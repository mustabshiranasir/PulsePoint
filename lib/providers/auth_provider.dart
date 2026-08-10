import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _listenToAuthChanges();
  }

  // Listens to Firebase auth state changes and fetches Firestore details
  void _listenToAuthChanges() {
    _authService.userStream.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        try {
          _currentUser = await _authService.getUserProfile(firebaseUser.uid);
        } catch (e) {
          // If Firestore document fails to fetch (e.g. not created yet or network issue)
          _currentUser = null;
        }
      } else {
        _currentUser = null;
      }
      _isInitialized = true;
      notifyListeners();
    });
  }

  // Log in
  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.login(email: email, password: password);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // Sign up
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? bloodGroup,
    bool? isAvailable,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
        bloodGroup: bloodGroup,
        isAvailable: isAvailable,
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // Log out
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
      _currentUser = null;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // Update donor availability in DB and local state
  Future<void> updateAvailability(bool isAvailable) async {
    if (_currentUser == null) return;
    _setLoading(true);
    try {
      await _authService.updateAvailability(_currentUser!.uid, isAvailable);
      _currentUser = UserModel(
        uid: _currentUser!.uid,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        role: _currentUser!.role,
        bloodGroup: _currentUser!.bloodGroup,
        isAvailable: isAvailable,
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // Helper to change loading state and notify UI
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
