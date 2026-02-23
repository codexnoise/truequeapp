# Getting Started

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.10.0
- [Dart SDK](https://dart.dev/get-dart) >= 3.10.0
- [Node.js](https://nodejs.org/) >= 18 (for Firebase Functions)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Android Studio or Xcode (for device emulation)
- A Firebase project with the following services enabled:
  - Authentication (Email/Password)
  - Cloud Firestore
  - Firebase Storage
  - Firebase Cloud Messaging (FCM)
  - Cloud Functions

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd truequeapp
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Install Firebase Functions dependencies

```bash
cd functions
npm install
cd ..
```

### 4. Configure Firebase

Connect the project to your Firebase project:

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart` with your project credentials.

### 5. Set up environment variables

Copy the example file and fill in your Firebase credentials:

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
# Firebase - Android
FIREBASE_ANDROID_API_KEY=your_android_api_key_here
FIREBASE_ANDROID_APP_ID=your_android_app_id_here

# Firebase - iOS
FIREBASE_IOS_API_KEY=your_ios_api_key_here
FIREBASE_IOS_APP_ID=your_ios_app_id_here
FIREBASE_IOS_BUNDLE_ID=your_ios_bundle_id_here

# Firebase - Shared
FIREBASE_MESSAGING_SENDER_ID=your_messaging_sender_id_here
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_STORAGE_BUCKET=your_storage_bucket_here
```

> **Note:** `.env` is gitignored. Never commit it to version control.

### 6. Run the app

```bash
flutter run
```

To run on a specific device:

```bash
flutter devices          # List available devices
flutter run -d <device-id>
```

## Environment Setup

### Android

The `android/app/build.gradle.kts` is configured with:

```kotlin
minSdk = flutter.minSdkVersion   // Minimum Android SDK
isCoreLibraryDesugaringEnabled = true  // Required for flutter_local_notifications
```

The `android/app/build.gradle.kts` dependencies include:

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### iOS

No additional configuration is required beyond the standard Flutter iOS setup. Push notification permissions are requested at runtime.

## Deploy Firebase Functions

```bash
npx firebase-tools deploy --only functions --project <your-project-id>
```

## Build for Release

### Android (App Bundle for Google Play)

```bash
flutter build appbundle
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Android (APK)

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ipa
```

## Running Tests

```bash
flutter test
```

## Useful Commands

| Command | Description |
|---|---|
| `flutter pub get` | Install dependencies |
| `flutter clean` | Clear build cache |
| `flutter analyze` | Run static analysis |
| `flutter run --release` | Run in release mode |
| `flutter build appbundle` | Build Android App Bundle |
| `npx firebase-tools functions:log --project <id>` | View Cloud Functions logs |
