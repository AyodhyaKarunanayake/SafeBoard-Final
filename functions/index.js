const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ── Route 87's physical seat map ─────────────────────────────────────────
// (kept in sync with lib/services/allocation_service.dart and
// lib/widgets/bus_diagram.dart, which implement/render this same
// structure client-side)
//   PRIORITY zone - rows 1-3, 5 seats/row (A,B left block / C,D,E right
//                   block)                                          = 15
//   GENERAL zone  - rows 4-6, same layout                           = 15
//   LIMITED zone  - rows 7-11 same layout (25) + row 12, a right-only
//                   3-seat row (C,D,E) beside the rear door, since the
//                   left side is taken up by the door itself (3) + row
//                   13, a 6-seat rear bench A-F with no left/right
//                   split (6)                                       = 34
//   STANDING      - a hard cap of 6, entirely separate from the 64 seats
//                   above - not tied to any row.
const PRIORITY_TOTAL_SEATS = 15;
const GENERAL_TOTAL_SEATS = 15;
const LIMITED_TOTAL_SEATS = 34;
const STANDING_CAPACITY = 6;

const PRIORITY_ROWS = [1, 2, 3];
const GENERAL_ROWS = [4, 5, 6];
const LIMITED_ROWS = [7, 8, 9, 10, 11, 12]; // + row 13 (the rear bench)
const EXTRA_RIGHT_ROW = 12;
const REAR_BENCH_ROW = 13;

// How strongly an opposite-gender neighbour counts against a candidate
// seat, read from `allocation_rules` if configured.
const DEFAULT_PROXIMITY_WEIGHT = 0.5;

// One row's seats in physical left-to-right order, split into the blocks
// that are contiguous ("sit together") groups. Rows 1-11 have an aisle
// between the 2-seat left block and the 3-seat right block; row 12 is
// right-only (no left pair - the rear door takes that space); row 13 is
// one unbroken 6-seat bench.
function rowBlocks(row) {
  if (row === REAR_BENCH_ROW) {
    return [[`${row}A`, `${row}B`, `${row}C`, `${row}D`, `${row}E`, `${row}F`]];
  }
  if (row === EXTRA_RIGHT_ROW) {
    return [[`${row}C`, `${row}D`, `${row}E`]];
  }
  return [
    [`${row}A`, `${row}B`],
    [`${row}C`, `${row}D`, `${row}E`],
  ];
}

function allSeatsInZone(zone) {
  if (zone === "priority") return PRIORITY_ROWS.flatMap((r) => rowBlocks(r).flat());
  if (zone === "general") return GENERAL_ROWS.flatMap((r) => rowBlocks(r).flat());
  if (zone === "limited") {
    return [...LIMITED_ROWS.flatMap((r) => rowBlocks(r).flat()), ...rowBlocks(REAR_BENCH_ROW).flat()];
  }
  return [];
}

function rowOfSeat(seatNumber) {
  return parseInt(/^(\d+)/.exec(seatNumber)[1], 10);
}

function neighborsOf(seatNumber) {
  const row = rowOfSeat(seatNumber);
  for (const block of rowBlocks(row)) {
    const idx = block.indexOf(seatNumber);
    if (idx === -1) continue;
    const neighbors = [];
    if (idx > 0) neighbors.push(block[idx - 1]);
    if (idx < block.length - 1) neighbors.push(block[idx + 1]);
    return neighbors;
  }
  return [];
}

function isPriorityEligible(passenger) {
  return passenger.safety_preference === true ||
    (passenger.mobility_status && passenger.mobility_status !== "none") ||
    passenger.pregnant === true;
}

// Primary passenger keeps first pick; among the rest, priority-eligible
// female companions are weighted ahead of other priority-eligible
// companions, who in turn go ahead of non-eligible ones - so when a scarce
// priority/adjacent seat can't fit everyone, an eligible female companion
// is the one seated first.
function orderForSelection(passengers) {
  if (passengers.length <= 1) return passengers;
  const [primary, ...rest] = passengers;
  rest.sort((a, b) => {
    const aEligible = isPriorityEligible(a);
    const bEligible = isPriorityEligible(b);
    const aFemaleEligible = aEligible && a.gender === "female";
    const bFemaleEligible = bEligible && b.gender === "female";
    if (aFemaleEligible !== bFemaleEligible) return aFemaleEligible ? -1 : 1;
    if (aEligible !== bEligible) return aEligible ? -1 : 1;
    return 0;
  });
  return [primary, ...rest];
}

/**
 * SafeBoard Allocation Engine Cloud Function.
 *
 * Allocation order (see lib/services/allocation_service.dart for the
 * client-side twin of this exact logic):
 *   1. Eligibility: safety_preference, mobility_status != 'none', or
 *      pregnant makes a passenger Priority-eligible. Among competing
 *      eligible passengers for the same seat, female passengers are
 *      weighted higher (see orderForSelection).
 *   2. Eligible -> try PRIORITY (nearest free seat to the front door) -
 *      UNLESS only 2 or fewer free priority seats remain, in which case
 *      those are reserved for passengers with a real mobility need or who
 *      are pregnant; a safety_preference-only passenger is bumped to
 *      General instead (flagged `priority_reserved: true`).
 *   3. Not eligible, or PRIORITY full/reserved -> try GENERAL: a two-stage
 *      pick - Stage A hard-filters out any seat with an opposite-gender
 *      neighbour, Stage B picks the lowest-row survivor (falling back to
 *      the lowest-row seat overall if every free seat has an
 *      opposite-gender neighbour).
 *   4. GENERAL full -> try LIMITED (same two-stage pick).
 *   5. PRIORITY, GENERAL and LIMITED all full -> STANDING, capped at 6.
 *   6. STANDING also full -> reject with "bus at capacity".
 *
 * `seat_count` (default 1) requests a group: adjacent seats are tried
 * first in a single zone (PRIORITY only if the whole group is eligible,
 * else starting at GENERAL, following the same zone fallback order), using
 * the same hard-filter-then-tiebreak approach across candidate blocks. If
 * every passenger in the group has opted in with `traveling_together:
 * true`, the hard filter is skipped between the group's OWN members (they
 * may sit adjacent regardless of gender) while still applying normally
 * against every other passenger on the bus. If no zone has a
 * large-enough gender-safe (or, failing that, simply free) contiguous
 * block, the group falls back to being allocated individually through
 * steps 1-5 above, rather than failing the whole request.
 */
exports.allocateSeat = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const {
    journey_id,
    bus_id,
    boarding_stop,
    alighting_stop,
    seat_count,
    passengers: passengersPayload,
  } = req.body;

  // Single-passenger requests carry their fields at the top level;
  // multi-seat requests carry one entry per passenger in `passengers`.
  const passengers = (Array.isArray(passengersPayload) && passengersPayload.length > 0)
    ? passengersPayload
    : [{
      passenger_id: req.body.passenger_id,
      gender: req.body.gender,
      mobility_status: req.body.mobility_status,
      safety_preference: req.body.safety_preference,
      pregnant: req.body.pregnant,
      traveling_together: req.body.traveling_together,
    }];
  const requestedCount = Math.max(1, seat_count || passengers.length);

  try {
    const journeyRef = db.collection("journey_instances").doc(journey_id);
    const journeySnap = await journeyRef.get();
    const journey = journeySnap.exists
      ? journeySnap.data()
      : { conductor_id: "COND_882" };

    // Load this bus's live seat state, or synthesize the full 64-seat
    // layout (all free) if none has been provisioned in Firestore yet.
    const seatsSnap = await db
      .collection("seats")
      .where("bus_id", "==", bus_id)
      .get();

    const occupiedGenderBySeat = {};
    let standingOccupied = 0;
    if (!seatsSnap.empty) {
      seatsSnap.forEach((doc) => {
        const s = doc.data();
        if (s.seat_zone === "standing") {
          if (s.current_status === "occupied") standingOccupied++;
          return;
        }
        if (s.current_status === "occupied" && s.seat_number) {
          occupiedGenderBySeat[s.seat_number] = s.occupied_by_gender || null;
        }
      });
    }
    standingOccupied = Math.min(standingOccupied, STANDING_CAPACITY);

    const rulesSnap = await db
      .collection("allocation_rules")
      .where("active_status", "==", true)
      .get();
    let proximityWeight = DEFAULT_PROXIMITY_WEIGHT;
    if (!rulesSnap.empty) {
      proximityWeight = rulesSnap.docs[0].data().weight_factor || DEFAULT_PROXIMITY_WEIGHT;
    }

    function isFree(seat) {
      return !(seat in occupiedGenderBySeat);
    }

    // Kept for other cosmetic risk-score computations (e.g. the group
    // adjacent-block path) - no longer used to DECIDE which seat
    // pickBestScoredSeat returns; see the hard-filter-then-tiebreak logic
    // below instead.
    function costFor(seat, gender) {
      let cost = rowOfSeat(seat) * 0.02;
      for (const neighbor of neighborsOf(seat)) {
        const occupant = occupiedGenderBySeat[neighbor];
        if (occupant && occupant !== gender) cost += 0.2 * proximityWeight;
      }
      return cost;
    }

    // True if none of [seat]'s physical neighbours are currently occupied
    // by someone of a different gender than [gender]. This is the Stage A
    // hard filter used by pickBestScoredSeat and (in a group-aware form)
    // by findAdjacentBlock.
    function isGenderSafeSeat(seat, gender) {
      for (const neighbor of neighborsOf(seat)) {
        const occupant = occupiedGenderBySeat[neighbor];
        if (occupant && occupant !== gender) return false;
      }
      return true;
    }

    function compareByRowThenLetter(a, b) {
      return rowOfSeat(a) - rowOfSeat(b) || a.localeCompare(b);
    }

    // Nearest-to-front free priority seat, gender-safety hard-filtered the
    // same way General/Limited are: among free priority seats (sorted by
    // row/letter), prefer the nearest one with no opposite-gender
    // neighbour; if every free priority seat has one, fall back to the
    // plain nearest free seat, so a priority-need passenger is never
    // rejected outright just because no gender-safe seat exists.
    function pickNearestPrioritySeat(exclude, gender) {
      const free = allSeatsInZone("priority").filter((s) => isFree(s) && !exclude.has(s));
      if (free.length === 0) return null;
      free.sort(compareByRowThenLetter);

      const genderSafe = free.filter((s) => isGenderSafeSeat(s, gender));
      const candidates = genderSafe.length > 0 ? genderSafe : free;
      return candidates[0];
    }

    // Two-stage selection, used for both General and Limited zones:
    //   Stage A (hard filter) - keep only free seats with no opposite-
    //   gender neighbour.
    //   Stage B (soft tiebreak) - pick the lowest-row seat among survivors
    //   (alphabetical tiebreak); if nothing survives the hard filter
    //   (every free seat has an opposite-gender neighbour), fall back to
    //   the same tiebreak across every free seat in the zone, ignoring
    //   gender.
    function pickBestScoredSeat(zone, gender, exclude) {
      const free = allSeatsInZone(zone).filter((s) => isFree(s) && !exclude.has(s));
      if (free.length === 0) return null;

      const genderSafe = free.filter((s) => isGenderSafeSeat(s, gender));
      const candidates = genderSafe.length > 0 ? genderSafe : free;
      candidates.sort(compareByRowThenLetter);
      return candidates[0];
    }

    // Gender-safety check for a candidate group window: for each seat in
    // the window (assigned to the passenger at the same index in
    // [genders]), every neighbour must either be a fellow group member
    // (exempted when [travelingTogether]) or - for neighbours outside the
    // window, i.e. real, possibly-already-occupied seats belonging to
    // someone else on the bus - not of a different gender. The hard filter
    // always applies to outside neighbours, traveling_together or not.
    function windowIsGenderSafe(window, genders, travelingTogether) {
      for (let i = 0; i < window.length; i++) {
        const seat = window[i];
        const passengerGender = genders[i];
        for (const neighbor of neighborsOf(seat)) {
          const neighborIndexInWindow = window.indexOf(neighbor);
          if (neighborIndexInWindow !== -1) {
            if (travelingTogether) continue; // fellow group member - mutually exempted
            if (genders[neighborIndexInWindow] !== passengerGender) return false;
          } else {
            const occupant = occupiedGenderBySeat[neighbor];
            if (occupant && occupant !== passengerGender) return false;
          }
        }
      }
      return true;
    }

    // Searches each row's contiguous blocks, in zone row order, for
    // genders.length free seats sitting next to each other - the "book a
    // group together" case.
    //   Stage A (hard filter) - among windows that fit and are entirely
    //   free, prefer one where every seat is gender-safe (see
    //   windowIsGenderSafe); opposite-gender members of THIS SAME group
    //   are exempted from each other when [travelingTogether].
    //   Stage B (soft tiebreak) - the first (lowest-row) gender-safe
    //   window wins; if none exists anywhere in the zone, fall back to the
    //   first free window regardless of gender, so the group still gets
    //   seated together.
    function findAdjacentBlock(zone, genders, travelingTogether) {
      const count = genders.length;
      const rows = zone === "priority" ? PRIORITY_ROWS : zone === "general" ? GENERAL_ROWS : [...LIMITED_ROWS, REAR_BENCH_ROW];

      let fallbackWindow = null;
      for (const row of rows) {
        for (const block of rowBlocks(row)) {
          if (block.length < count) continue;
          for (let start = 0; start + count <= block.length; start++) {
            const window = block.slice(start, start + count);
            if (!window.every((s) => isFree(s))) continue;

            if (!fallbackWindow) fallbackWindow = window;
            if (windowIsGenderSafe(window, genders, travelingTogether)) return window;
          }
        }
      }
      return fallbackWindow;
    }

    // 2 or fewer free priority seats left -> reserved for passengers with
    // a real mobility need or who are pregnant; a passenger who is only
    // priority-eligible via safety_preference is bumped to General instead
    // (flagged via priority_reserved) rather than taking one of the last
    // priority seats from someone who needs it more.
    const PRIORITY_RESERVE_THRESHOLD = 2;

    // The core per-passenger algorithm (steps 1-5). Mutates the in-memory
    // occupancy state as it goes, so a group's individual fallback never
    // double-books a seat.
    function allocateOne(passenger, exclude) {
      let priorityReserved = false;
      if (isPriorityEligible(passenger)) {
        const freeCount = allSeatsInZone("priority").filter((s) => isFree(s) && !exclude.has(s)).length;
        const hasStrongPriorityNeed = (passenger.mobility_status && passenger.mobility_status !== "none") || passenger.pregnant === true;
        if (freeCount <= PRIORITY_RESERVE_THRESHOLD && !hasStrongPriorityNeed) {
          priorityReserved = true; // safety_preference-only - falls through, flagged for the UI
        } else {
          const seat = pickNearestPrioritySeat(exclude, passenger.gender);
          if (seat) return { seatNumber: seat, zone: "priority", riskScore: 0.05, priorityReserved: false };
        }
      }

      const generalSeat = pickBestScoredSeat("general", passenger.gender, exclude);
      if (generalSeat) {
        const risk = 0.1 + (isGenderSafeSeat(generalSeat, passenger.gender) ? 0.0 : 0.15);
        return { seatNumber: generalSeat, zone: "general", riskScore: risk, priorityReserved };
      }

      const limitedSeat = pickBestScoredSeat("limited", passenger.gender, exclude);
      if (limitedSeat) {
        const risk = 0.2 + (isGenderSafeSeat(limitedSeat, passenger.gender) ? 0.0 : 0.15);
        return { seatNumber: limitedSeat, zone: "limited", riskScore: risk, priorityReserved };
      }

      if (standingOccupied < STANDING_CAPACITY) {
        const slot = standingOccupied + 1;
        const ratio = standingOccupied / STANDING_CAPACITY;
        return { seatNumber: `Standing-${slot}`, zone: "standing", riskScore: 0.5 + ratio * 0.3, priorityReserved };
      }

      return null; // bus at capacity
    }

    function commit(result, passenger) {
      if (result.zone === "standing") {
        standingOccupied++;
      } else {
        occupiedGenderBySeat[result.seatNumber] = passenger.gender;
      }
    }

    // ANALYTICS_LOG - best-effort, fire-and-forget (never awaited, never
    // throws into the allocation flow), exactly like the seat_allocations
    // write below. Written for evaluation/analysis, not read back by the
    // app itself.
    let analyticsCounter = 0;
    function logAnalyticsEvent(data) {
      const logId = `log_${Date.now()}_${analyticsCounter++}`;
      db.collection("analytics_log").doc(logId).set({
        log_id: logId,
        timestamp: new Date().toISOString(),
        journey_id: journey_id,
        bus_id: bus_id,
        route_id: route_id,
        ...data,
      }).catch(() => {});
    }

    // ── Run the group (or single-passenger) allocation ──────────────────
    const allEligible = passengers.every(isPriorityEligible);
    const zoneOrder = allEligible ? ["priority", "general", "limited"] : ["general", "limited"];
    const travelingTogetherAll = passengers.every((p) => p.traveling_together === true);

    // Seat-assignment order is decided up front (gender-weighted, primary
    // first) so the adjacency search can check each candidate window
    // against the actual genders that would end up sitting in it.
    const ordered = orderForSelection(passengers);
    const genders = ordered.map((p) => p.gender);

    let block = null;
    let blockZone = null;
    if (requestedCount > 1) {
      for (const zone of zoneOrder) {
        block = findAdjacentBlock(zone, genders, travelingTogetherAll);
        if (block) {
          blockZone = zone;
          break;
        }
      }
      logAnalyticsEvent({
        event_type: "group_booking_outcome",
        zone: blockZone,
        seat_count: passengers.length,
        seating_mode: block ? "adjacent" : "individual_fallback",
        traveling_together: travelingTogetherAll,
      });
    }

    const allocationsByPassenger = new Map();
    if (block) {
      for (let i = 0; i < block.length; i++) {
        const seat = block[i];
        const p = ordered[i];
        occupiedGenderBySeat[seat] = p.gender;
        const riskScore = blockZone === "priority" ? 0.05 : (blockZone === "general" ? 0.1 : 0.2) + costFor(seat, p.gender);
        allocationsByPassenger.set(p, { seatNumber: seat, zone: blockZone, riskScore, priorityReserved: false });
        logAnalyticsEvent({
          event_type: "seat_allocated",
          zone: blockZone,
          gender: p.gender,
          risk_score: riskScore,
          priority_reserved: false,
        });
      }
    } else {
      for (const p of ordered) {
        const result = allocateOne(p, new Set());
        if (!result) {
          logAnalyticsEvent({ event_type: "allocation_rejected", gender: p.gender });
          return res.status(400).json({ error: "Bus at capacity - no seats or standing room left." });
        }
        commit(result, p);
        allocationsByPassenger.set(p, result);
        logAnalyticsEvent({
          event_type: "seat_allocated",
          zone: result.zone,
          gender: p.gender,
          risk_score: result.riskScore,
          priority_reserved: result.priorityReserved === true,
        });
      }
    }

    // Persist one allocation record per passenger, in original order.
    const results = [];
    for (const p of passengers) {
      const result = allocationsByPassenger.get(p);
      const allocId = `alloc_${Date.now()}_${results.length}`;
      const bookingId = `bk_${Date.now()}_${results.length}`;
      const qrCode = `SB-${journey_id}-${result.seatNumber}-${allocId}`;

      const allocationData = {
        allocation_id: allocId,
        booking_id: bookingId,
        passenger_id: p.passenger_id,
        seat_id: result.seatNumber,
        seat_number: result.seatNumber,
        bus_id: bus_id,
        journey_id: journey_id,
        allocation_datetime: new Date().toISOString(),
        boarding_stop: boarding_stop,
        alighting_stop: alighting_stop,
        allocation_type: "auto",
        zone: result.zone,
        risk_score: result.riskScore,
        status: "active",
        qr_code: qrCode,
        priority_reserved: result.priorityReserved === true,
      };
      await db.collection("seat_allocations").doc(allocId).set(allocationData);

      results.push({
        allocationId: allocId,
        seatNumber: result.seatNumber,
        zone: result.zone,
        riskScore: result.riskScore,
        qrCode: qrCode,
        priority_reserved: result.priorityReserved === true,
      });
    }

    await journeyRef.set(
      { current_occupancy: admin.firestore.FieldValue.increment(passengers.length) },
      { merge: true }
    );

    try {
      await admin.messaging().send({
        notification: {
          title: passengers.length > 1 ? "New Group Allocated" : "New Passenger Allocated",
          body: passengers.length > 1
            ? `${passengers.length} passengers allocated at ${boarding_stop}`
            : `Passenger allocated to Seat ${results[0].seatNumber} (${results[0].zone.toUpperCase()}) at ${boarding_stop}`,
        },
        topic: `conductor_${journey.conductor_id || "all"}`,
      });
    } catch (fcmErr) {
      console.log("FCM push notification simulated");
    }

    // Single-seat requests keep the original flat response shape;
    // multi-seat requests also include the full `results` array.
    return res.status(200).json({
      ...results[0],
      results,
    });
  } catch (error) {
    console.error("Allocation engine error:", error);
    return res.status(500).json({ error: error.message });
  }
});
