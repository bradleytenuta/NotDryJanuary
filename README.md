# notdryjanuary

A Flutter mobile project for building a location-based map experience.

## Getting Started

### What is Flutter?

Flutter is Google's UI toolkit for building high-performance, natively compiled
applications from a single Dart codebase. You can build Android, iOS, web, and
desktop apps with one shared project.

### Why use Flutter?

- Fast development with hot reload.
- One codebase for multiple platforms.
- Strong widget-based UI system.
- Good performance on real devices.

### Developer Setup

1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
2. Install Android Studio (or VS Code with Flutter and Dart extensions).
3. Run Flutter doctor to verify your environment:

```bash
flutter doctor
```

4. Fetch project dependencies:

```bash
flutter pub get
```

5. List available devices:

```bash
flutter devices
```

## Development Commands

### Run the app

Run on Chrome:

```bash
flutter run -d chrome
```

List all connected/available devices:

```bash
flutter devices
```

Run on the connected Android device with ID 39201JEHN06666:

```bash
flutter run -d 39201JEHN06666
```

### Compile and Build

Build Android APK (debug):

```bash
flutter build apk --debug
```

Build Android APK (release):

```bash
flutter build apk --release
```

Build Android App Bundle for Play Store:

```bash
flutter build appbundle --release
```

Build iOS (from macOS with Xcode installed):

```bash
flutter build ios --release
```

### Test and Verify

Run static analysis:

```bash
flutter analyze
```

Run unit/widget tests:

```bash
flutter test
```

## Helpful Resources

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.