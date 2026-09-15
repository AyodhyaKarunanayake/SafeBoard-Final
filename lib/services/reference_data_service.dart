import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/route_model.dart';
import '../models/conductor.dart';
import '../models/bus_template.dart';

// Reads/seeds the `routes`, `conductors` and `buses` reference-data
// collections. These are static/reference (not transactional) data, so the
// read side matters as much as the write side - BookingProvider actually
// rebuilds its bus timetable from what this service returns when Firestore
// is reachable, rather than writing data nobody ever reads back.
//
// Follows the same graceful-degradation convention as every other service
// in the app: never throws into the caller, returns null/no-ops when
// Firestore is unreachable, and the caller always has a static fallback to
// use instead.
class ReferenceDataService {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // Seeds each of the three collections from the given fallback data, but
  // only if that collection is currently empty - so this is safe to call
  // on every app start without ever overwriting live data.
  Future<void> seedIfEmpty({
    required List<RouteModel> routes,
    required List<Conductor> conductors,
    required List<BusTemplate> busTemplates,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      await _seedCollectionIfEmpty(
        firestore,
        'routes',
        routes.map((r) => MapEntry(r.routeId, r.toMap())),
      );
      await _seedCollectionIfEmpty(
        firestore,
        'conductors',
        conductors.map((c) => MapEntry(c.conductorId, c.toMap())),
      );
      await _seedCollectionIfEmpty(
        firestore,
        'buses',
        busTemplates.map((b) => MapEntry(b.busId, b.toMap())),
      );
    } catch (_) {
      // Graceful offline execution
    }
  }

  Future<void> _seedCollectionIfEmpty(
    FirebaseFirestore firestore,
    String collection,
    Iterable<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    final existing = await firestore.collection(collection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = firestore.batch();
    for (final entry in docs) {
      batch.set(firestore.collection(collection).doc(entry.key), entry.value);
    }
    await batch.commit();
  }

  Future<List<RouteModel>?> fetchRoutes() async {
    try {
      final firestore = _firestore;
      if (firestore == null) return null;
      final snapshot = await firestore.collection('routes').get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.map((d) => RouteModel.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<Conductor>?> fetchConductors() async {
    try {
      final firestore = _firestore;
      if (firestore == null) return null;
      final snapshot = await firestore.collection('conductors').get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.map((d) => Conductor.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<BusTemplate>?> fetchBusTemplates() async {
    try {
      final firestore = _firestore;
      if (firestore == null) return null;
      final snapshot = await firestore.collection('buses').get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.map((d) => BusTemplate.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return null;
    }
  }
}
