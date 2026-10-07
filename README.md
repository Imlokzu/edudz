# edudz

A calm, self-hosted EduPage companion for Android. A real fork of
[DislikesSchool/EduPage2](https://github.com/DislikesSchool/EduPage2), with a new
interface and our existing EduPage2 backend.

**[Download the Android APK](https://github.com/Imlokzu/edudz/releases/latest)**

## Using edudz

1. Install the release APK on Android 7.0 or newer.
2. Enter your school's EduPage subdomain (or its full `school.edupage.org` URL),
   your EduPage username and password.
3. Your timetable, homework, grades and messages load from your school through
   our own backend at `https://ep2.waveio.me`.

The demo on the sign-in screen is explicitly labeled and uses sample data.
Use the avatar to switch Ukrainian, English or German, choose a dark theme,
refresh your data, or sign out.

## What's in this fork

- Redesigned Today, Schedule, Tasks, Grades and Inbox screens.
- Warm paper, forest-green accents, bundled Manrope, a new edudz mark.
- A new Android application ID, `me.waveio.edudz`: installs beside EduPage2.
- No Firebase startup, upstream analytics, Sentry or Shorebird updates.
- Credentials and session token in platform secure storage on Android.
- Cached school data stays available when the internet or backend is unavailable.
- Independent refresh errors; a failed section doesn't discard the other data.
- Task checkmarks are local to the device; they do not submit work to EduPage.
- Grade values retain the school's scale.
- Existing EduPage2 message details, attachment and reply support remain available.

## Screenshots

Screenshots in `docs/screenshots/` use demo data only.

<p>
  <img src="docs/screenshots/today.png" width="220" alt="edudz Today screen, demo data">
  <img src="docs/screenshots/schedule.png" width="220" alt="edudz timetable, demo data">
  <img src="docs/screenshots/tasks.png" width="220" alt="edudz homework, demo data">
</p>

## Build

Flutter 3.47.5 / Dart 3.13.4, Android SDK 36, JDK 17.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release signing is configured via `android/key.properties` and a local keystore;
these files are never committed. For your own builds, generate your own release
keystore and set `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`.
The original installation's signing key is preserved locally for our releases.

The backend URL may be set at compile time:

```sh
flutter build apk --release --dart-define=EDUDZ_SERVER_URL=https://your-server.example
```

Only use an HTTPS server you control: it receives your EduPage sign-in details.
The server implementation is [EduPage2-server](https://github.com/DislikesSchool/EduPage2-server).
Our existing local server, operational notes and school compatibility patches
are at `~/edupage2/server` and `~/edupage2/SETUP.md`.

## Validation

Widget/unit tests cover form validation, school-host normalization, secure storage,
demo navigation, completing tasks, theme switching, sign-out and compact-screen
layouts at enlarged text size. The Android integration test lives in
`integration_test/app_test.dart`.

This release targets Android. iOS, desktop and web platform directories are
inherited from upstream and are not release-validated here. Push notifications
and the upstream iCanteen flow are not part of the new navigation.

## License and attribution

GPL-3.0, as required by the upstream project; see [LICENSE](LICENSE).
Original EduPage2 by DislikesSchool / vyPal and contributors.
edudz interface and self-hosted integration by Imlokzu.
Manrope is bundled under its SIL Open Font License in `assets/fonts/OFL.txt`.
This is an independent client and is not affiliated with aSc EduPage.
