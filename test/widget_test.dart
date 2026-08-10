import 'package:flutter_test/flutter_test.dart';
import 'package:pulsepoint/main.dart';

void main() {
  testWidgets('App displays error screen when Firebase initialization fails', (WidgetTester tester) async {
    // Build our app with mock firebase initialization failure.
    await tester.pumpWidget(const PulsePointApp(
      firebaseInitialized: false,
      firebaseError: 'Mock initialization error for testing',
    ));

    // Verify that the Firebase error screen is shown.
    expect(find.text('Firebase Initialization Error'), findsOneWidget);
  });
}
