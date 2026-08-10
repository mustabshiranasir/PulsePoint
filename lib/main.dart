import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/blood_request_provider.dart';
import 'screens/login_screen.dart';
import 'screens/donor_dashboard.dart';
import 'screens/requester_dashboard.dart';
import 'services/notification_service.dart';
import 'models/cached_request.dart';
import 'screens/donor_tracking_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  String? firebaseError;

  try {
    // Attempt standard Firebase initialization.
    await Firebase.initializeApp();
    firebaseInitialized = true;
    
    // Initialize Notifications
    NotificationService.initialize(navigatorKey);
    NotificationService.setupTerminatedState(navigatorKey);
  } catch (e) {
    firebaseError = e.toString();
  }

  try {
    // Initialize Hive
    await Hive.initFlutter();
    Hive.registerAdapter(CachedRequestAdapter());
    await Hive.openBox<CachedRequest>('cached_requests');
  } catch (e) {
    print("Error initializing Hive: $e");
  }

  runApp(PulsePointApp(
    firebaseInitialized: firebaseInitialized,
    firebaseError: firebaseError,
  ));
}

class PulsePointApp extends StatelessWidget {
  final bool firebaseInitialized;
  final String? firebaseError;

  const PulsePointApp({
    super.key,
    required this.firebaseInitialized,
    required this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BloodRequestProvider()),
      ],
      child: MaterialApp(
        title: 'PulsePoint',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        routes: {
          '/request_details': (context) {
            final String requestId = ModalRoute.of(context)!.settings.arguments as String;
            return DonorTrackingScreen(requestId: requestId);
          },
        },
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFC62828), // PulsePoint Emergency Red
            primary: const Color(0xFFC62828),
            secondary: const Color(0xFF0D47A1), // Trust Blue
            surface: Colors.grey[50],
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC62828), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
          ),
        ),
        home: firebaseInitialized
            ? const AuthGate()
            : FirebaseErrorScreen(error: firebaseError),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Show loading/splash screen if Provider isn't initialized yet
    if (!authProvider.isInitialized) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC62828), Color(0xFF0D47A1)], // Red to Blue emergency theme
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'PulsePoint',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connecting...',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If user is not logged in, redirect to login
    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    final user = authProvider.currentUser;
    // Auth is active but user profile data from Firestore is still loading
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Dynamic routing depending on role saved in user profile document
    if (user.role == 'donor') {
      return const DonorDashboard();
    } else {
      return const RequesterDashboard();
    }
  }
}

class FirebaseErrorScreen extends StatelessWidget {
  final String? error;
  const FirebaseErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Firebase Initialization Error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'PulsePoint could not connect to the database. Please make sure you have added native config files (google-services.json for Android, GoogleService-Info.plist for iOS) or configured firebase options.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Error Details:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
