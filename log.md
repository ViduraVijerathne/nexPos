# Development Log

## 2026-04-08

- Created a reusable theme foundation with `AppColors` and `AppTheme`.
- Added `google_fonts` and applied the Inter text theme across the app.
- Replaced the default Flutter counter screen with a simple POS starter dashboard.
- Updated the widget test to validate the new app shell and starter content.
- Formatted the codebase with `dart format lib test`.
- Verified the project with `flutter test` and confirmed all tests passed.
- Removed the runtime `google_fonts` dependency to prevent offline font loading failures.
- Switched the shared app theme to an offline-safe local text theme with sensible fallbacks.
- Re-synced macOS CocoaPods with `pod install` after the workspace reported `Manifest.lock` was out of sync.
- Verified the desktop target with `flutter build macos --debug` and confirmed the macOS app builds successfully.
