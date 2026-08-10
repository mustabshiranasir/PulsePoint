# PulsePoint - Blood Donation & Emergency Request Platform

PulsePoint is a real-time, location-aware Flutter application designed to bridge the gap between blood requesters (hospitals or patients) and nearby blood donors. The app uses Firebase for real-time data sync and Cloud Messaging (FCM) for push notifications, featuring local offline caching with Hive, background geofencing matching, and a responsive UI.

---

## Features

### 1. Push Notifications & Matching (FCM)
* **Real-time Permissions:** Requests notification permission on user registration and login.
* **FCM Token Registry:** Saves FCM tokens under the donor's user document in Firestore and refreshes them automatically upon token rotation.
* **Geofenced Notifications:** A Cloud Function listens to new blood requests, queries matching donors of that blood group, filters them mathematically to a **10km radius** using the Haversine formula, and sends target push notifications containing the `requestId` payload.

### 2. In-App Notification Handling
* **Foreground Banners:** Shows an in-app notification banner using the `flutter_local_notifications` package if a notification arrives while the app is in focus.
* **Deep Linking Navigation:** Handles tapping on notification alerts across foreground, background, and terminated app states to automatically route the user directly to the corresponding request tracking screen.

### 3. Offline Caching (Hive)
* **Typed Hive Model:** Defines a lightweight `CachedRequest` model adapter to store lists locally.
* **Automatic Cache Syncing:** Caches the donor's fetched requests and the requester's own request history automatically upon fetch.
* **Offline Fallbacks:** Detects connectivity loss and falls back to rendering cached data accompanied by a "Last Updated" timestamp banner.

### 4. Interactive History & Profiles
* **History Screen:** Shows completed and cancelled requests for both donors and requesters, with a seamless fallback to Hive cache if offline.
* **Donor Profile:** Lists donor credentials, total completed donations count, and an availability toggle switch that updates Firestore status in real-time.
* **Navigation Drawer:** Unified side menu for intuitive dashboard navigation.

### 5. UI Polish & Theme
* **Emergency Theme:** Red-and-blue emergency theme complete with gradient splash screens.
* **Async Indicators:** Global loaders and loading skeletons during asynchronous database writes or GPS acquisition.
* **Consistent Error Handling:** Snackbar alerts for network, permission, or database write failures.

---

## Tech Stack
* **Framework:** Flutter (Dart)
* **Backend:** Firebase (Auth, Firestore, Messaging, Cloud Functions)
* **Local Caching:** Hive & Hive Flutter (Local NoSQL Database)
* **Serverless Backend:** Node.js (Firebase Admin SDK & Functions SDK)
* **Maps & Positioning:** Geolocator, Latlong2, Flutter Map

---

## Getting Started

### Prerequisites
* Flutter SDK (3.12.x+)
* Node.js (version 18 recommended) for Cloud Functions
* Firebase CLI installed (`npm install -g firebase-tools`)

### Setup Instructions

1. **Setup Firebase Config Files:**
   * Place `google-services.json` in the `android/app/` directory.

2. **Install Flutter Dependencies:**
   Run the following command at the root of the project to solve and fetch all package dependencies:
   ```bash
   flutter pub get
   ```

3. **Generate Hive Adapters:**
   If the cached models need to be compiled, run the builder:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Deploying Firebase Cloud Functions:**
   * Move into the functions directory:
     ```bash
     cd functions
     ```
   * Install npm dependencies:
     ```bash
     npm install
     ```
   * Deploy the function to your Firebase project:
     ```bash
     firebase deploy --only functions
     ```

5. **Build/Run Application:**
   ```bash
   flutter build apk --debug
   flutter run
   ```
