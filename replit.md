# VET DICT+

A comprehensive veterinary dictionary and educational mobile application built with Flutter, running as a Flutter Web app in Replit.

## Project Overview

VET DICT+ is a veterinary reference app for students and professionals covering drugs, diseases, terminology, tests, lab normal ranges, instruments, books, slides, and more. The app supports both English and Kurdish (Sorani) languages with RTL support.

## Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Local Database:** SQLite (sqflite) for offline data storage
- **Networking:** HTTP / Dio for API communication
- **PDF Viewer:** Syncfusion Flutter PDF Viewer
- **Authentication:** Google Sign-In
- **Push Notifications:** OneSignal (mobile only)

## Architecture

- `lib/main.dart` — App entry point and main home page
- `lib/config/app_config.dart` — App configuration (API URLs, OAuth IDs)
- `lib/database/` — SQLite database helpers
- `lib/models/` — Data models (Drug, Disease, Word, etc.)
- `lib/pages/` — UI screens (drugs, diseases, quiz, favorites, etc.)
- `lib/providers/` — State management (auth, theme, language, font size)
- `lib/services/` — Business logic (API, sync, OneSignal, secure storage)
- `lib/utils/` — Constants and helpers
- `lib/widgets/` — Reusable UI components
- `assets/` — Images, fonts, icons

## Running in Replit

The workflow builds the Flutter web app and serves it with Python's HTTP server on port 5000:

```
flutter build web && python3 -m http.server 5000 --directory build/web --bind 0.0.0.0
```

## Configuration

The app uses `lib/config/app_config.dart` for configuration values. For production deployments, these can be set via `--dart-define` build flags:

- `API_BASE_URL` — Backend API URL
- `GOOGLE_CLIENT_ID_IOS` — Google Sign-In iOS client ID
- `GOOGLE_SERVER_CLIENT_ID` — Google Sign-In server client ID
- `ONESIGNAL_APP_ID` — OneSignal push notification app ID

## Notes

- OneSignal push notifications are mobile-only and will show harmless errors on web
- The native splash screen plugin only runs on mobile/native targets
- `sqflite` (SQLite) has a web implementation that uses IndexedDB
- Web rendering uses HTML renderer (Skia/CanvasKit fallback)

## User Preferences

- Keep Flutter version compatibility in mind; `activeThumbColor` was removed in Flutter 3.32
