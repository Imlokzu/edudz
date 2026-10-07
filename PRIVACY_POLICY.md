# edudz privacy

edudz sends your EduPage credentials to the configured self-hosted EduPage2 server
so it can authenticate against your school. The default server is ep2.waveio.me.
Android stores your credentials and session token in encrypted platform secure
storage. The app keeps timetable, homework, grades and messages in local
preferences to make them available offline; these school-data caches are not
independently encrypted. Signing out removes the account and these caches.

The app disables Android automatic backup and contains no Firebase, Sentry,
Shorebird, advertising or third-party analytics integration. Links opened in an
external browser are subject to the destination's own privacy policy.

Completion checkmarks are local and are not sent to the school. The demo doesn't
use a real school account. Do not configure someone else's backend unless you
trust them with your EduPage account.

The current backend is hosted on our Mac; it can be unavailable while that
machine sleeps or loses its internet connection. Cached data remains available.

## School assistant

When you ask the assistant, the server reads relevant data from your authenticated
school session and sends it together with your chat messages to the configured
model API. The current installation uses NVIDIA NIM. This can include timetable,
room/teacher names, assignments, grades, messages and selected attachment text or
page images. School passwords and the server's model key are not sent as context.
The model API's own data policies apply. The assistant has read-only school tools.

Downloaded attachment copies are cached in the app's private temporary directory.
Files explicitly saved to Downloads remain on the device after sign-out or app
removal. Office previews show text, not the document's full original layout.
