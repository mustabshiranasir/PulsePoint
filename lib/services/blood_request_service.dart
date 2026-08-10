import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../models/blood_request_model.dart';

class BloodRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _collection =
      _firestore.collection('blood_requests');

  // Create a new blood request
  Future<void> createRequest({
    required String requesterId,
    required String patientName,
    required String bloodGroupNeeded,
    required int unitsNeeded,
    required String hospitalName,
    required double latitude,
    required double longitude,
    required String urgencyLevel,
  }) async {
    try {
      final docRef = _collection.doc();
      final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));

      final newRequest = BloodRequestModel(
        id: docRef.id,
        requesterId: requesterId,
        patientName: patientName,
        bloodGroupNeeded: bloodGroupNeeded,
        unitsNeeded: unitsNeeded,
        hospitalName: hospitalName,
        hospitalLocation: geoFirePoint.data,
        urgencyLevel: urgencyLevel,
        status: 'pending',
        createdAt: DateTime.now(),
        acceptedByDonorId: null,
      );

      await docRef.set(newRequest.toMap());
    } catch (e) {
      throw Exception('Failed to post blood request: ${e.toString()}');
    }
  }

  // Stream of requests for a specific requester (hospitals/patients)
  Stream<List<BloodRequestModel>> streamRequesterRequests(String requesterId) {
    return _collection
        .where('requesterId', isEqualTo: requesterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Stream of nearby pending requests matching donor's blood group
  Stream<List<BloodRequestModel>> streamNearbyPendingRequests({
    required String bloodGroup,
    required double donorLat,
    required double donorLng,
    double radiusInKm = 10.0,
  }) {
    final center = GeoFirePoint(GeoPoint(donorLat, donorLng));
    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(_collection);

    return geoCollection
        .subscribeWithin(
          center: center,
          radiusInKm: radiusInKm,
          field: 'hospitalLocation',
          geopointFrom: (data) =>
              (data['hospitalLocation'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
        )
        .map((docSnapshots) {
      // Filter in Dart for reliability and index simplicity
      final List<BloodRequestModel> requests = docSnapshots
          .map((doc) => BloodRequestModel.fromMap(doc.data()!, doc.id))
          .where((req) => req.status == 'pending' && req.bloodGroupNeeded == bloodGroup)
          .toList();

      // Sort by urgency, then distance
      requests.sort((a, b) {
        const urgencyPriority = {'critical': 3, 'high': 2, 'normal': 1};
        final priorityA = urgencyPriority[a.urgencyLevel] ?? 0;
        final priorityB = urgencyPriority[b.urgencyLevel] ?? 0;

        if (priorityA != priorityB) {
          return priorityB.compareTo(priorityA); // Highest urgency first
        }

        // Distance sorting (closest first)
        final distA = center.distanceBetweenInKm(geopoint: a.geoPoint);
        final distB = center.distanceBetweenInKm(geopoint: b.geoPoint);
        return distA.compareTo(distB);
      });

      return requests;
    });
  }

  // Accept a blood request atomically using a transaction to prevent race conditions
  Future<void> acceptRequest({
    required String requestId,
    required String donorId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _collection.doc(requestId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('Blood request does not exist.');
        }

        final String currentStatus = snapshot.data()?['status'] ?? 'pending';
        if (currentStatus != 'pending') {
          throw Exception('This request has already been $currentStatus.');
        }

        transaction.update(docRef, {
          'status': 'accepted',
          'acceptedByDonorId': donorId,
        });
      });
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
