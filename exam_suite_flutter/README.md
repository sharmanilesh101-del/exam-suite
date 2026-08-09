# Exam Duty & Remuneration Suite (Flutter)

A native Flutter port of the two web tools: the exam Duty Chart Generator and the
Remuneration & TA-DA Statement Generator, in one app with a module switcher at the top.

## What's included
- **Duty Chart module**: Staff, Exam Slots, Generate (least-loaded-first allocation,
  conflict-free, backlog-aware), Summary & Export.
- **Remuneration module**: Rate Setup, Staff Directory, Examiner Entries, Supporting
  Staff, Staff Summary & Export. Internal examiner remuneration floors at Rs. 280;
  Expert Assistant is auto-zeroed for OR; batches auto-suggest (12/batch PR, 20/batch OR).
- **"Send assignments to Remuneration"** button on the Duty Chart's Export tab — turns a
  generated chart into Remuneration entries automatically (Internal Examiner → Internal
  examiner entries, Expert → External examiner entries, Technical Assistant + Peon → one
  Supporting Staff entry per slot).
- Local persistence via `shared_preferences` (data survives closing the app, day-by-day
  entry through the month is fine).
- Export to **Word (.doc)** (HTML written with a `.doc` extension, which Word opens
  natively — same trick as the web version) and **Excel (.xlsx)** via the `excel`
  package, shared through the OS share sheet (`share_plus`) so you can save to Drive,
  email it, or open it directly.
- JSON backup: share a full backup, or restore by pasting JSON back in.

## Setup

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.19 or
   newer — the app uses the current Material 3 `WidgetStateProperty` API).
2. Unzip this project, then from its root folder:
   ```
   flutter pub get
   flutter run
   ```
   `flutter run` needs a connected device, a running emulator, or a browser
   (`flutter run -d chrome` works too, since everything here is pure Dart/Flutter with
   no platform-specific code).
3. To build a release APK:
   ```
   flutter build apk --release
   ```
   The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.

## Notes
- This was written and reviewed carefully, but **wasn't compiled in the environment
  that generated it** (no Flutter SDK available there) — if `flutter pub get` or
  `flutter run` surfaces a small API mismatch (package versions shift their APIs
  fairly often, especially the `excel` package), it should be a quick fix. Paste the
  error back if you'd like help resolving it.
- CSV bulk-import (available in the web version for Staff and Exam Slots) isn't in
  this build yet — everything else carried over. Say the word if you want that added.
- All monetary values are stored and computed as `double`; the original web app used
  plain JS numbers, so rounding should match, but double-check a few totals against
  the web version the first time you use this on a real exam cycle.
