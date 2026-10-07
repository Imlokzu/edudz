# edudz fork handoff — 2026-10-07

- Project: /Users/hhh/projects/edudz-mobile
- GitHub: https://github.com/Imlokzu/edudz, branch edudz
- Original working self-hosted app: /Users/hhh/edupage2/app
- Existing server: /Users/hhh/edupage2/server, local :8130, public https://ep2.waveio.me
- Previous operational context: /Users/hhh/edupage2/SETUP.md (2026-09-29)
- Existing web project: /Users/hhh/projects/edudz (separate project)

## Code

main.dart now boots without Firebase, Sentry or Shorebird. New screens, state and
design tokens are in lib/edudz. Original EduPage2 API models and message detail
flows remain. SchoolController initializes and synchronizes those models.
User.saveToCache/loadFromCache/clearCache now use FlutterSecureStorage; account
changes and sign-out remove the school caches. Completion markers are device-local.

Android package and namespace: me.waveio.edudz. Version: 2.0.0+27.
Release signing material is local and ignored. Never commit it.

## Checks

- flutter analyze: no issues.
- 17 widget/unit tests: pass, including a 360px screen at 1.3 text scale.
- Android integration: demo navigation through all tabs and dark theme: pass.
- Real school data: public server login and local backend timetable/timeline/grades
  endpoints respond; private live Dart test confirms all model adapters parse.
- Signed release APK: real EduPage sign-in and all four data tabs verified.
- Native session restore and offline cache notice verified after app restart.
- Native screenshots in docs/screenshots use explicitly marked demo data only.

The installed Homebrew Dart launcher hangs in dyld on this Mac. Isolated SDK
~/.cache/edudz-flutter works; scripts/flutter-local.sh uses it. This is a local
build workaround, not a requirement for other contributors.

## Operational limits

The server runs on the Mac via me.waveio.ep2-server and me.waveio.ep2-tunnel;
Mac sleep or lost internet can interrupt it. Do not restart or replace the server
as part of a cosmetic app change. Moving to the WSL2 server is separate work.
Android is the validated release platform. Inherited iOS/desktop/web directories
are not release-validated. Local caches of school data use SharedPreferences;
only credentials and session token use encrypted platform storage.
