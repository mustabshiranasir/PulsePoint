import 'package:flutter/material.dart';
import '../services/blood_request_service.dart';
import '../models/blood_request_model.dart';

class BloodRequestProvider with ChangeNotifier {
  final BloodRequestService _requestService = BloodRequestService();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // Stream of own requests (for requester dashboard)
  Stream<List<BloodRequestModel>> streamRequesterRequests(String requesterId) {
    return _requestService.streamRequesterRequests(requesterId);
  }

  // Stream single request details (for live tracking/map views)
  Stream<BloodRequestModel?> streamRequest(String requestId) {
    return _requestService.streamRequest(requestId);
  }

  // Stream of nearby matching requests (for donor dashboard list)
  Stream<List<BloodRequestModel>> streamNearbyPendingRequests({
    required String bloodGroup,
    required double donorLat,
    required double donorLng,
    double radiusInKm = 10.0,
  }) {
    return _requestService.streamNearbyPendingRequests(
      bloodGroup: bloodGroup,
      donorLat: donorLat,
      donorLng: donorLng,
      radiusInKm: radiusInKm,
    );
  }

  // Stream of donor's currently accepted request
  Stream<List<BloodRequestModel>> streamDonorActiveRequests(String donorId) {
    return _requestService.streamDonorActiveRequests(donorId);
  }

  // Create request (captures requesterPhone)
  Future<void> createRequest({
    required String requesterId,
    required String requesterPhone,
    required String patientName,
    required String bloodGroupNeeded,
    required int unitsNeeded,
    required String hospitalName,
    required double latitude,
    required double longitude,
    required String urgencyLevel,
  }) async {
    _setLoading(true);
    try {
      await _requestService.createRequest(
        requesterId: requesterId,
        requesterPhone: requesterPhone,
        patientName: patientName,
        bloodGroupNeeded: bloodGroupNeeded,
        unitsNeeded: unitsNeeded,
        hospitalName: hospitalName,
        latitude: latitude,
        longitude: longitude,
        urgencyLevel: urgencyLevel,
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // Accept request (captures donorPhone)
  Future<void> acceptRequest({
    required String requestId,
    required String donorId,
    required String donorPhone,
  }) async {
    _setLoading(true);
    try {
      await _requestService.acceptRequest(
        requestId: requestId,
        donorId: donorId,
        donorPhone: donorPhone,
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // Update donor live location
  Future<void> updateDonorLocation(String requestId, double latitude, double longitude) async {
    await _requestService.updateDonorLocation(requestId, latitude, longitude);
  }

  // Update request status (e.g. completed, cancelled)
  Future<void> updateRequestStatus(String requestId, String status) async {
    _setLoading(true);
    try {
      await _requestService.updateRequestStatus(requestId, status);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
