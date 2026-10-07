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

## 2.1 update — tablet, materials and assistant

- Optional school field; the signed server token supplies the detected school.
- Navigation rail at 700px; lesson/homework detail pane at 1000px.
- Lesson room/teachers/class/group, published curriculum and related homework.
- Material cards and authenticated attachment previews; Android MediaStore downloads.
- A real streaming assistant with stop/retry, source-file chips and read-only tools.
- Server fork: https://github.com/Imlokzu/edudz-server, local ~/edupage2/server.
- Private model config: ~/.config/edudz-ai/config.json (0600), existing NVIDIA account.
  Main: Llama 3.2 90B; image transcription: Llama 3.2 11B. No key in the APK.
- PDFKit helper: tools/pdf-preview.swift, compiled to ~/.config/edudz-ai/pdf-preview.
- SSE keepalives and a three-minute stream receive timeout cover scanned-file reads.
- Latest checks: 23 Flutter tests, clean analysis, Android tablet integration,
  native PDF preview and actual Downloads file creation; Go feature/race tests.
- Real automatic school login and lesson-plan endpoint verified on the public server.
- Real school PDF (366194 bytes) was fetched and read by the assistant; its final
  Ukrainian explanation arrived as 106 stream events. Private test data stays out
  of the repository. Large/scanned attachments can take longer to analyze.

## 2.1.1 — actual Dio stream decoder fix

The old SSE test supplied Stream<List<int>>, while Dio returns Stream<Uint8List>.
Dart's runtime generic checks rejected Utf8Decoder when the actual typed byte
stream reached Stream.transform; the server then observed a canceled request.
The decoder now casts the stream to List<int> before UTF-8 conversion.
A regression test uses actual Uint8List chunks, split Unicode and keepalives.
24 Flutter tests and clean analysis pass. A live Dart/Dio request through
https://ep2.waveio.me for the German tomorrow-homework question received
status, 21 token events and done. No backend or account changes are required.
