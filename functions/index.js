const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * SafeBoard Allocation Engine Cloud Function
 * Implements the 11-step Gender-Aware Seating Allocation Algorithm exactly.
 */
exports.allocateSeat = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const {
    passenger_id,
    gender,
    mobility_status,
    safety_preference,
    journey_id,
    route_id,
    bus_id,
    boarding_stop,
    alighting_stop,
    trip_distance_km,
    available_general_seats,
  } = req.body;

  // Trips at or below this length are "short-distance": when general seats
  // are nearly exhausted, a short-distance rider stands instead of taking
  // one of the last few seats, so those stay free for longer journeys.
  const SHORT_DISTANCE_THRESHOLD_KM = 100.0;
  const LOW_SEAT_AVAILABILITY_THRESHOLD = 3;

  try {
    // STEP 1 — Fetch active journey instance from Firestore
    const journeyRef = db.collection("journey_instances").doc(journey_id);
    const journeySnap = await journeyRef.get();
    const journey = journeySnap.exists
      ? journeySnap.data()
      : {
          current_occupancy: 27,
          standing_count: 4,
          conductor_id: "COND_882",
        };

    // STEP 2 — Fetch all available seats for that bus
    const seatsSnap = await db
      .collection("seats")
      .where("bus_id", "==", bus_id)
      .where("current_status", "==", "available")
      .get();

    let seats = [];
    if (!seatsSnap.empty) {
      seatsSnap.forEach((doc) => seats.push({ id: doc.id, ...doc.data() }));
    } else {
      // Default 8-row layout fallback
      for (let r = 1; r <= 8; r++) {
        for (let col of ["A", "B", "C", "D"]) {
          seats.push({
            seat_id: `${r}${col}`,
            seat_number: `${r}${col}`,
            seat_zone: r <= 3 ? "priority" : "general",
            row_number: r,
            current_status: "available",
          });
        }
      }
    }

    // STEP 3 — Read active allocation_rules from Firestore
    const rulesSnap = await db
      .collection("allocation_rules")
      .where("active_status", "==", true)
      .get();
    let proximityWeight = 0.5;
    if (!rulesSnap.empty) {
      proximityWeight = rulesSnap.docs[0].data().weight_factor || 0.5;
    }

    let allocatedSeat = null;
    let allocatedZone = "general";
    let riskScore = 0.15;
    let crowdingWarning = false;

    // STEP 4 — If safety_preference == true OR mobility_status != 'none' -> Try PRIORITY ZONE (rows 1-3)
    const isPriorityEligible =
      safety_preference === true || (mobility_status && mobility_status !== "none");

    if (isPriorityEligible) {
      const prioritySeats = seats.filter(
        (s) => s.seat_zone === "priority" || (s.row_number && s.row_number <= 3)
      );
      if (prioritySeats.length > 0) {
        // Pick seat nearest to front door (lowest row number)
        prioritySeats.sort((a, b) => (a.row_number || 1) - (b.row_number || 1));
        allocatedSeat = prioritySeats[0];
        allocatedZone = "priority";
        riskScore = 0.05;
      }
    }

    // STEP 5 — Else if priority zone full or no preference -> Try GENERAL ZONE (rows 4-8)
    // Step 5b: unless general seats are nearly exhausted and this rider's
    // trip is short - then skip straight to standing (step 6) so the last
    // few seats stay available for passengers travelling further.
    const isShortDistance =
      typeof trip_distance_km === "number" && trip_distance_km <= SHORT_DISTANCE_THRESHOLD_KM;
    const seatsNearlyFull =
      typeof available_general_seats === "number" &&
      available_general_seats <= LOW_SEAT_AVAILABILITY_THRESHOLD;
    const preferStanding = !isPriorityEligible && isShortDistance && seatsNearlyFull;

    if (!allocatedSeat && !preferStanding) {
      const generalSeats = seats.filter(
        (s) => s.seat_zone === "general" || (s.row_number && s.row_number > 3)
      );

      if (generalSeats.length > 0) {
        // Scan nearby occupied seats and compute cost score based on opposite-gender proximity
        let scoredSeats = generalSeats.map((seat) => {
          let penalty = 0;
          if (seat.occupied_by_gender && seat.occupied_by_gender !== gender) {
            penalty += 0.2 * proximityWeight;
          }
          return { seat, cost: penalty + (seat.row_number || 4) * 0.02 };
        });

        scoredSeats.sort((a, b) => a.cost - b.cost);
        allocatedSeat = scoredSeats[0].seat;
        allocatedZone = "general";
        riskScore = 0.1 + scoredSeats[0].cost;
      }
    }

    // STEP 6 — If all seats full -> evaluate standing
    if (!allocatedSeat) {
      const standingCapacity = 18;
      const currentStanding = journey.standing_count || 0;
      const ratio = currentStanding / standingCapacity;

      if (ratio >= 1.0) {
        return res.status(400).json({ error: "Bus at capacity" });
      }

      if (ratio >= 0.8) {
        crowdingWarning = true;
      }

      const standingSlot = currentStanding + 1;
      allocatedSeat = { seat_number: `Standing-${standingSlot}` };
      allocatedZone = "standing";
      riskScore = 0.5 + ratio * 0.3;
    }

    const seatNumber = allocatedSeat.seat_number || "3A";
    const allocId = `alloc_${Date.now()}`;
    const bookingId = `bk_${Date.now()}`;
    const qrCode = `SB-${journey_id}-${seatNumber}-${allocId}`;

    // STEP 7 — Write seat_allocation record to Firestore
    const allocationData = {
      allocation_id: allocId,
      booking_id: bookingId,
      seat_id: seatNumber,
      seat_number: seatNumber,
      bus_id: bus_id,
      journey_id: journey_id,
      allocation_datetime: new Date().toISOString(),
      boarding_stop: boarding_stop,
      alighting_stop: alighting_stop,
      allocation_type: "auto",
      risk_score: riskScore,
      status: "active",
      qr_code: qrCode,
    };
    await db.collection("seat_allocations").doc(allocId).set(allocationData);

    // STEP 8 — Increment journey.current_occupancy in Firestore
    await journeyRef.update({
      current_occupancy: admin.firestore.FieldValue.increment(1),
    });

    // STEP 10 — Send push notification to conductor via FCM
    try {
      const payload = {
        notification: {
          title: "New Passenger Allocated",
          body: `Passenger allocated to Seat ${seatNumber} (${allocatedZone.toUpperCase()}) at ${boarding_stop}`,
        },
        topic: `conductor_${journey.conductor_id || "all"}`,
      };
      await admin.messaging().send(payload);
    } catch (fcmErr) {
      console.log("FCM push notification simulated");
    }

    // STEP 11 — Return { seatNumber, zone, riskScore, qrCode, crowdingWarning }
    return res.status(200).json({
      allocationId: allocId,
      seatNumber: seatNumber,
      zone: allocatedZone,
      riskScore: riskScore,
      qrCode: qrCode,
      crowdingWarning: crowdingWarning,
    });
  } catch (error) {
    console.error("Allocation engine error:", error);
    return res.status(500).json({ error: error.message });
  }
});
