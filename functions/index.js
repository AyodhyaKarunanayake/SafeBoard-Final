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
 *   2. Eligible -> try PRIORITY (nearest free seat to the front door).
 *   3. Not eligible, or PRIORITY full -> try GENERAL (opposite-gender /
 *      row-distance cost-scored).
 *   4. GENERAL full -> try LIMITED (same cost-scoring).
 *   5. PRIORITY, GENERAL and LIMITED all full -> STANDING, capped at 6.
 *   6. STANDING also full -> reject with "bus at capacity".
 *
 * `seat_count` (default 1) requests a group: adjacent seats are tried
 * first in a single zone (PRIORITY only if the whole group is eligible,
 * else starting at GENERAL, following the same zone fallback order); if no
 * zone has a large-enough contiguous block, the group falls back to being
 * allocated individually through steps 1-5 above, rather than failing the
 * whole request.
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

    function costFor(seat, gender) {
      let cost = rowOfSeat(seat) * 0.02;
      for (const neighbor of neighborsOf(seat)) {
        const occupant = occupiedGenderBySeat[neighbor];
        if (occupant && occupant !== gender) cost += 0.2 * proximityWeight;
      }
      return cost;
    }

    function pickNearestPrioritySeat(exclude) {
      const free = allSeatsInZone("priority").filter((s) => isFree(s) && !exclude.has(s));
      if (free.length === 0) return null;
      free.sort((a, b) => rowOfSeat(a) - rowOfSeat(b) || a.localeCompare(b));
      return free[0];
    }

    function pickBestScoredSeat(zone, gender, exclude) {
      const free = allSeatsInZone(zone).filter((s) => isFree(s) && !exclude.has(s));
      if (free.length === 0) return null;
      free.sort((a, b) => costFor(a, gender) - costFor(b, gender) || a.localeCompare(b));
      return free[0];
    }

    function findAdjacentBlock(zone, count) {
      const rows = zone === "priority" ? PRIORITY_ROWS : zone === "general" ? GENERAL_ROWS : [...LIMITED_ROWS, REAR_BENCH_ROW];
      for (const row of rows) {
        for (const block of rowBlocks(row)) {
          if (block.length < count) continue;
          for (let start = 0; start + count <= block.length; start++) {
            const window = block.slice(start, start + count);
            if (window.every((s) => isFree(s))) return window;
          }
        }
      }
      return null;
    }

    // The core per-passenger algorithm (steps 1-5). Mutates the in-memory
    // occupancy state as it goes, so a group's individual fallback never
    // double-books a seat.
    function allocateOne(passenger, exclude) {
      if (isPriorityEligible(passenger)) {
        const seat = pickNearestPrioritySeat(exclude);
        if (seat) return { seatNumber: seat, zone: "priority", riskScore: 0.05 };
      }

      const generalSeat = pickBestScoredSeat("general", passenger.gender, exclude);
      if (generalSeat) {
        return { seatNumber: generalSeat, zone: "general", riskScore: 0.1 + costFor(generalSeat, passenger.gender) };
      }

      const limitedSeat = pickBestScoredSeat("limited", passenger.gender, exclude);
      if (limitedSeat) {
        return { seatNumber: limitedSeat, zone: "limited", riskScore: 0.2 + costFor(limitedSeat, passenger.gender) };
      }

      if (standingOccupied < STANDING_CAPACITY) {
        const slot = standingOccupied + 1;
        const ratio = standingOccupied / STANDING_CAPACITY;
        return { seatNumber: `Standing-${slot}`, zone: "standing", riskScore: 0.5 + ratio * 0.3 };
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

    // ── Run the group (or single-passenger) allocation ──────────────────
    const allEligible = passengers.every(isPriorityEligible);
    const zoneOrder = allEligible ? ["priority", "general", "limited"] : ["general", "limited"];

    let block = null;
    let blockZone = null;
    if (requestedCount > 1) {
      for (const zone of zoneOrder) {
        block = findAdjacentBlock(zone, requestedCount);
        if (block) {
          blockZone = zone;
          break;
        }
      }
    }

    const allocationsByPassenger = new Map();
    if (block) {
      const ordered = orderForSelection(passengers);
      for (let i = 0; i < block.length; i++) {
        const seat = block[i];
        const p = ordered[i];
        occupiedGenderBySeat[seat] = p.gender;
        const riskScore = blockZone === "priority" ? 0.05 : (blockZone === "general" ? 0.1 : 0.2) + costFor(seat, p.gender);
        allocationsByPassenger.set(p, { seatNumber: seat, zone: blockZone, riskScore });
      }
    } else {
      const ordered = orderForSelection(passengers);
      for (const p of ordered) {
        const result = allocateOne(p, new Set());
        if (!result) {
          return res.status(400).json({ error: "Bus at capacity - no seats or standing room left." });
        }
        commit(result, p);
        allocationsByPassenger.set(p, result);
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
      };
      await db.collection("seat_allocations").doc(allocId).set(allocationData);

      results.push({
        allocationId: allocId,
        seatNumber: result.seatNumber,
        zone: result.zone,
        riskScore: result.riskScore,
        qrCode: qrCode,
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
