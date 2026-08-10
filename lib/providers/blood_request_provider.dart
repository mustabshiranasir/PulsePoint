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

  // Stream of nearby matching requests (for donor dashboard)
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

  // Create request
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
    _setLoading(true);
    try {
      await _requestService.createRequest(
        requesterId: requesterId,
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

  // Accept request
  Future<void> acceptRequest({
    required String requestId,
    required String donorId,
  }) async {
    _setLoading(true);
    try {
      await _requestService.acceptRequest(
        requestId: requestId,
        donorId: donorId,
      );
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
