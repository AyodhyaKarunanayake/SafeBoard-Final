import 'package:cloud_firestore/cloud_firestore.dart';

class AllocationTraceService {
  Future<void> writeTrace({
    required String journeyId,
    required String passengerGender,
    required List<Map<String, dynamic>> steps,
    required String? selectedSeat,
    required String? selectedZone,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('allocation_trace').add({
        'journey_id': journeyId,
        'passenger_gender': passengerGender,
        'steps': steps,
        'selected_seat': selectedSeat,
        'selected_zone': selectedZone,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never let trace logging affect a real booking.
    }
  }
}
