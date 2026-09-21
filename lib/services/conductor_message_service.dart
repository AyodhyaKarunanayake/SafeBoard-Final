import 'package:cloud_firestore/cloud_firestore.dart';

// A reply the conductor sent to one of this passenger's messages.
class ConductorReplyRecord {
  final String text;
  final DateTime? sentAt;

  const ConductorReplyRecord({required this.text, required this.sentAt});
}

// One "Text the conductor" message this passenger sent, with any replies.
class ConductorMessageRecord {
  final String id;
  final String seatNumber;
  final String text;
  final DateTime? sentAt;
  final String status; // 'sent' | 'read' | 'replied'
  final List<ConductorReplyRecord> replies;

  const ConductorMessageRecord({
    required this.id,
    required this.seatNumber,
    required this.text,
    required this.sentAt,
    required this.status,
    required this.replies,
  });

  factory ConductorMessageRecord.fromMap(Map<String, dynamic> map, String docId) {
    final rawReplies = map['replies'];
    return ConductorMessageRecord(
      id: (map['message_id'] ?? docId).toString(),
      seatNumber: (map['seat_number'] ?? '').toString(),
      text: (map['message_text'] ?? '').toString(),
      sentAt: DateTime.tryParse((map['sent_datetime'] ?? '').toString()),
      status: (map['status'] ?? 'sent').toString(),
      replies: [
        if (rawReplies is List)
          for (final r in rawReplies)
            if (r is Map)
              ConductorReplyRecord(
                text: (r['text'] ?? '').toString(),
                sentAt: DateTime.tryParse((r['sent_datetime'] ?? '').toString()),
              ),
      ],
    );
  }
}

// Sends a passenger's "Text the conductor" message through the
// `conductor_messages` collection, where the conductor app shows it live and
// can reply, and streams this passenger's messages back with those replies.
//
// Follows the same graceful-degradation convention as every other service in
// the app: never throws into the caller, and no-ops (or returns an empty
// stream) when Firestore is unreachable. The send is fire-and-forget, like
// the app's other writes, so the sheet behaves exactly as it did before.
class ConductorMessageService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void send({
    required String journeyId,
    required String busId,
    required String passengerId,
    required String seatNumber,
    required String text,
  }) {
    try {
      final firestore = _firestore;
      if (firestore == null) return;
      final now = DateTime.now();
      final id = 'msg_${now.millisecondsSinceEpoch}';
      firestore.collection('conductor_messages').doc(id).set({
        'message_id': id,
        'journey_id': journeyId,
        'bus_id': busId,
        'passenger_id': passengerId,
        'seat_number': seatNumber,
        'message_text': text,
        'sent_datetime': now.toIso8601String(), // ISO string, like every date in the app
        'status': 'sent',
      });
    } catch (_) {
      // Best-effort only - the sheet already confirmed to the passenger.
    }
  }

  // This passenger's messages for one journey, oldest first, with the
  // conductor's replies. Empty (never an error) when offline.
  Stream<List<ConductorMessageRecord>> watchMyMessages({
    required String passengerId,
    required String journeyId,
  }) {
    try {
      final firestore = _firestore;
      if (firestore == null) return Stream.value(const []);
      return firestore
          .collection('conductor_messages')
          .where('passenger_id', isEqualTo: passengerId)
          .snapshots()
          .map((snapshot) {
        final items = <ConductorMessageRecord>[
          for (final doc in snapshot.docs)
            if ((doc.data()['journey_id'] ?? '').toString() == journeyId)
              ConductorMessageRecord.fromMap(doc.data(), doc.id),
        ];
        items.sort((a, b) {
          final ta = a.sentAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.sentAt?.millisecondsSinceEpoch ?? 0;
          return ta.compareTo(tb);
        });
        return items;
      }).handleError((_) {});
    } catch (_) {
      return Stream.value(const []);
    }
  }
}
