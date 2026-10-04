# Pass the Spark

Pass the Spark is a Semester 4 individual mobile development project for higher education.

The project is based on the case **"Flexibility without losing community"**, exploring how students can have flexibility in when and how they participate in education while still feeling connected to fellow students and their school community.

## Technology

- Flutter
- Dart
- Android + iOS targets

## Project status

The first **Today home-screen prototype** is implemented with local preview data.
The prompt carousel, group cards and tab navigation work locally. Group/Journey/Profile destinations are read-only previews; answering, authentication, Firebase and NFC are not implemented yet. See [current iteration and next steps](docs/planning/current-iteration.md).

## Getting started

1. Clone the repository:
   ```bash
   git clone https://github.com/Ynwmisa/Pass-The-Spark.git
   cd Pass-The-Spark
   ```
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Current structure

- `lib/screens/`
- `lib/widgets/`
- `lib/models/`
- `lib/services/`
- `lib/utilities/`

The implementation also separates app routing, shared theme tokens and repositories. See docs/planning/codebase-structure.md for the intended responsibilities.

## Running on the Android emulator

Start an Android emulator, then run `flutter devices` and `flutter run -d emulator-5554` from this project folder (use the device ID shown on your machine).

If PowerShell does not recognise Flutter, restart the terminal/editor after adding C:\Users\mjbos\flutter\bin to your user PATH. To run immediately in an existing terminal:

```powershell
& 'C:\Users\mjbos\flutter\bin\flutter.bat' run -d emulator-5554
```

The Android runner is included. iOS runner completion and iOS execution remain separate work and require macOS/Xcode.
