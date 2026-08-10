import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth changes
  Stream<User?> get userStream => _auth.authStateChanges();

  // Get current user ID
  String? get currentUid => _auth.currentUser?.uid;

  // Fetch user profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load user profile: ${e.toString()}');
    }
  }

  // Stream user profile from Firestore in real-time
  Stream<UserModel?> streamUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserModel.fromMap(snapshot.data()!, uid);
      }
      return null;
    });
  }

  // Sign up user (Auth + Firestore document creation)
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    String? bloodGroup,
    bool? isAvailable,
  }) async {
    try {
      // 1. Create user in Firebase Auth
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;

      // Get FCM Token
      String? fcmToken;
      try {
        await FirebaseMessaging.instance.requestPermission().timeout(const Duration(seconds: 3));
        fcmToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
      } catch (e) {
        print("Error getting FCM token: $e");
      }

      // 2. Create the user model
      final UserModel newUser = UserModel(
        uid: uid,
        name: name.trim(),
        phone: phone.trim(),
        role: role,
        bloodGroup: role == 'donor' ? bloodGroup : null,
        isAvailable: role == 'donor' ? (isAvailable ?? false) : null,
        fcmToken: fcmToken,
      );

      // 3. Save details to Firestore
      await _firestore.collection('users').doc(uid).set(newUser.toMap());

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception('Database error: ${e.message ?? 'Unknown error occurred.'}');
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Login user
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Sign in with Auth
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;

      // 2. Fetch user profile from Firestore
      UserModel? profile = await getUserProfile(uid);
      if (profile == null) {
        throw Exception('User profile not found in database.');
      }

      // Update FCM token on login
      try {
        await FirebaseMessaging.instance.requestPermission().timeout(const Duration(seconds: 3));
        String? token = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
        if (token != null && token != profile.fcmToken) {
          await _firestore.collection('users').doc(uid).update({'fcmToken': token});
          profile = UserModel(
            uid: profile.uid,
            name: profile.name,
            phone: profile.phone,
            role: profile.role,
            bloodGroup: profile.bloodGroup,
            isAvailable: profile.isAvailable,
            fcmToken: token,
            location: profile.location,
          );
        }
      } catch (e) {
         print("Error updating FCM token on login: $e");
      }

      return profile!;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to log out: ${e.toString()}');
    }
  }

  // Map Firebase Auth errors to user-friendly messages
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  // Update donor availability
  Future<void> updateAvailability(String uid, bool isAvailable) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isAvailable': isAvailable,
      });
    } catch (e) {
      throw Exception('Failed to update availability: ${e.toString()}');
    }
  }
}

