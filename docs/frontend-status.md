# UWAY Frontend Status

Updated 25 October 2026. This note describes the current frontend source and separates implemented UI from API gaps and checks not yet run.

## Passenger Flutter app

| Screen or flow | Current status |
| --- | --- |
| Trip list and details with ordered route stops | Connected to existing Passenger trip and route read APIs |
| Trip Intent and drop-off | Connected to create, read, change, and cancel endpoints; the screen explains that this is not a reservation |
| Live tracking | Existing REST refresh and SignalR subscription are displayed on an OpenStreetMap map; location is available without Trip Intent |
| Notification inbox | Connected to the Passenger inbox and mark-read endpoints |
| Account/settings | Shows the local development role/API and explains missing account endpoints |
| Login, registration, past-trip history, general problem reports | Not available; the current API has no identity, history, or report endpoints |

## Driver Flutter app

| Screen or flow | Current status |
| --- | --- |
| Assigned trips and route stops | Connected to the Driver-only assigned-trip and route read APIs |
| Start/end and delay | Connected to existing lifecycle endpoints |
| Bus Nearly Full | Connected to the existing assigned-driver report endpoint |
| Live GPS | Source requests foreground location permission and posts device points through the existing trip location endpoint while the trip screen is open |
| Completed trips and local account details | Shown from assigned-trip data and build-time development identity |
| Emergency alerts, general reports/image attachments, messaging, background GPS | Not available in the current API/client |

## Admin React dashboard

| Screen or flow | Current status |
| --- | --- |
| Overview and API health | Uses live counts from existing API reads and checks `/health` |
| Source stops map | Existing 86-point GeoJSON view retained, with original coordinates and source groups |
| Stop, route, bus, driver management | Create, edit, search, and delete use existing Admin endpoints; API relationship constraints remain authoritative |
| Trip management | Create, search/filter, and reasoned cancellation are connected; editing/reassigning trips is unavailable because there is no update endpoint |
| Active trip map and capacity | Reads latest locations and capacity for active trips and refreshes every 15 seconds; no simulated location data |
| Driver reports and notifications | Displays supported delay/near-full capabilities; general reports, communication, and an Admin notification inbox are unavailable in the API |

## Shared constraints

All three clients still use local development header authentication where configured. There is no real sign-in or registration, and these headers are not production authentication. The Flutter map loads OpenStreetMap tiles and attributes their contributors. The Driver GPS code is foreground-only. English is the current UI language; a complete Arabic translation and RTL pass remains to be implemented.

## Verification for this frontend change

- Admin production bundle: `npm run build` passed after the dashboard changes.
- Admin dashboard was opened in the existing browser. It showed `/health` as connected and loaded the existing stops, route, bus, driver, and scheduled trip records. No records were changed from the UI.
- `dart format` completed for the edited Dart files. `dart analyze lib` did not pass because the three new package imports are not present in the existing package configuration. `flutter pub get` stalled without output; direct verbose `dart pub get` exited with Windows code `-1073741816` while resolving package versions. A separate read-only request to `pub.dev` returned HTTP 200, so this looks like the local Dart Pub process/runtime rather than a simple network outage. Flutter analyze after dependency resolution, APK build, emulator navigation, GPS permission, GPS submission, and SignalR UI behavior are therefore not verified for this change.
- No API source, database schema, database record, or migration was changed.
