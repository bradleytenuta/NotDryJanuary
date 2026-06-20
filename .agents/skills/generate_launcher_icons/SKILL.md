---
name: Generate Launcher Icons
description: Re-generates launcher icons for Android and iOS using the flutter_launcher_icons package
---

# Generate Launcher Icons

This skill updates or re-generates mobile app launcher icons from the source icon asset.

## Usage
Run the following commands in the workspace root:
```powershell
flutter pub get
dart run flutter_launcher_icons
```

## Configuration
The launcher icon configuration is located in `flutter_launcher_icons.yaml`.
- Source icon: `assets/icons/app-icon.png`
- Adaptive icon foreground: `assets/icons/app-icon.png`
- Adaptive icon background: `#FFFFFF`
