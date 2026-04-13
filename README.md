# Event Counter - Day Counter & Tracker

[![Flutter](https://img.shields.io/badge/Flutter-Stable-02569B.svg?logo=flutter)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-00BFA5.svg)](https://riverpod.dev)
[![Hive](https://img.shields.io/badge/Storage-Hive-F4B400.svg)](https://pub.dev/packages/hive)
[![Firebase](https://img.shields.io/badge/Cloud-Firebase-FFCA28.svg?logo=firebase)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Event Counter is an offline-first day counter and habit tracker for Android and iOS. Track countdowns, count-ups, and daily streaks with local-first reliability and optional cloud backup.

## Offline-First Design
- Primary storage is local Hive. The app works fully offline in guest mode.
- Cloud backup is optional and enabled only when user signs in.
- Sync conflict policy: latest updatedAt timestamp wins.
- Pending cloud writes are retried when connectivity returns.

## Screenshots
- Placeholder: Home Screen
- Placeholder: Habits Screen
- Placeholder: Settings Screen

## Features
- Countdown and count-up events
- Daily habit streak tracking
- Offline-first Hive storage
- Optional Firebase Auth and Firestore sync
- Event reminders and daily habit reminders
- Home widget data bridge for nearest and top events
- Event image sharing cards
- JSON and CSV export
- Light/Dark/System theme
- Import from default JSON export file

## Firebase Setup
1. Create a Firebase project at https://console.firebase.google.com.
2. Add Android app and download google-services.json into android/app/.
3. Add iOS app and download GoogleService-Info.plist into ios/Runner/.
4. Enable Authentication providers: Google and Apple.
5. Enable Firestore Database in production mode.
6. Add Firestore security rules from firestore.rules.

### Firestore Rules
Use the rules in firestore.rules:

rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /users/{userId}/{document=**} {
			allow read, write: if request.auth != null
												 && request.auth.uid == userId;
		}
	}
}

## Android Setup Notes
1. Confirm com.google.gms.google-services is applied in android/app/build.gradle.
2. Confirm Google services classpath exists in android/build.gradle.
3. Keep google-services.json out of version control (.gitignore already configured).
4. Ensure notification permissions exist in AndroidManifest.xml.

## iOS Setup Notes
1. Set minimum iOS to 13.0 in ios/Podfile.
2. Add Sign In with Apple capability in Xcode Runner target.
3. Add reversed client id URL scheme from Firebase iOS config to Info.plist.
4. Keep GoogleService-Info.plist out of version control (.gitignore already configured).

## Installation
1. Install Flutter stable SDK.
2. Clone this repository.
3. Run flutter pub get.
4. Run dart run build_runner build --delete-conflicting-outputs.
5. Run flutter run.

## Branding Asset Regeneration
- Source logos:
  - `assets/branding/full_colored_logo.png`
  - `assets/branding/monochrome_logo.png`
- Regenerate app icons after updating branding assets:
  - `dart run flutter_launcher_icons`
- Regenerate native splash assets:
  - `dart run flutter_native_splash:create`

## CI
GitHub Actions workflow runs:
- flutter analyze
- flutter test
- flutter build apk --release

## Contributing
1. Fork the repo and create a feature branch.
2. Add tests for new behavior and update docs.
3. Keep offline-first behavior intact (local writes must never depend on cloud).
4. Open a pull request with change summary, screenshots, and test notes.

## License
MIT. See LICENSE.
