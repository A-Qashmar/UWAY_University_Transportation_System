# UWAY Verification Status

## Frontend update — 25 October 2026

- Admin React dashboard source now has edit/delete forms for stops, routes, buses and drivers, trip search/status filtering, reasoned trip cancellation, API health indication, live active-trip location and capacity monitoring, and an explicit list of API gaps. The existing 86-point Source Map is retained.
- `npm run build` in `admin/` completed successfully after these changes.
- Passenger Flutter source now includes an OpenStreetMap live-location view and account/settings explanation. Driver Flutter source now includes an opt-in foreground GPS stream that posts to the existing location API, account details, and completed-trip list. The user-provided logo was added to both client assets.
- `dart format` completed for the edited Dart files. `dart analyze lib` reported unresolved `flutter_map`, `geolocator`, and `latlong2` imports because the existing package configuration is stale. `flutter pub get` stalled; a verbose direct `dart pub get` exited with Windows code `-1073741816` during package-version requests. A separate read-only `pub.dev` request returned HTTP 200. Flutter analyze/build and emulator behavior for these changes were not verified. The new package dependencies still need resolution.
- The Admin dashboard was inspected in the open browser: `/health` displayed connected and existing database-backed Admin lists appeared. This was a read-only visual check; no record was created, edited, or deleted.
- No backend, migration, database, or existing data was changed. The frontend gaps and verification boundary are detailed in [frontend-status.md](frontend-status.md).

Updated 24 October 2026. This log separates source implementation from checks
that were actually observed. No database reset, migration, commit, or push was
performed in this review.

## Requirements and PR2 focus

PR1 defines the Passenger trip browse/intent/drop-off/tracking/notification flow,
Driver trip operations and operational reports, and Admin route/stop/fleet/trip
management. It excludes reservations, QR boarding, and boarding confirmation.
The Gantt places PR2 on October 26–31, 2026. Its progress values and displayed
"Today" date are stale, so the team should update the schedule before using it
as a completion report. The practical demonstration priority is setup route and
trip data in Admin, browse it as a Passenger, then operate the assigned trip as
a Driver.

## Verified in this review

- Existing changes were retained. The project has many pre-existing uncommitted
  files; nothing was reset or committed.
- `http://127.0.0.1:5251/health` returned HTTP 200 with `Healthy`; Passenger
  reads and changes against that API returned database-backed results.
- PostgreSQL credentials were not printed. The API health check confirms its
  database connection. Direct Docker CLI access from this shell was denied by
  the Docker Desktop named pipe, so container status was not independently
  checked here.
- An existing Admin-created development route, stop, bus, and driver were
  available. A second synthetic stop was added to that test route and a
  scheduled demo trip was created through the API; the route now has two
  ordered stops. These records are retained as a small demo fixture, and the
  Passenger Trip Intent created during the UI check was cancelled.
- The Passenger app was already installed and running on the Android emulator.
  `adb reverse tcp:5251 tcp:5251` was active. The actual app loaded the scheduled
  trip, opened its details and ordered route stops, created a Trip Intent,
  changed the selected drop-off stop, and cancelled the intent. The API then
  returned HTTP 404 for that passenger's active intent, and the inbox endpoint
  returned an empty list. The app's Inbox empty state was observed on screen.
- Passenger Trip Intent is explicitly presented as non-reservation and not a
  seat hold. Expected rider count was 1 while the test intent was active.
- The Passenger API returned the scheduled trip while hiding bus/driver
  assignment fields, as intended by its read response. Route stops remained
  visible to the Passenger.
- A second API instance built from the current source on port 5252 returned
  HTTP 200 for `GET /api/trips/assigned` for driver 17 and an empty list for
  driver 1. A Passenger received HTTP 403 on that Driver-only endpoint. The
  development authentication headers remain local-only.
- The Admin React dashboard and a basic Driver screen are implemented in
  source. The Admin UI successfully created an additional scheduled test trip;
  Passenger browse showed it, and the no-intent Scheduled test trip was
  removed through the guarded API (`DELETE` returned HTTP 204). The trip form
  now reads its datetime-local value from the submitted form instead of stale
  React state.
- `npm run build` passed after the Admin form change. The API build passed with
  zero warnings and errors when directed to a separate output folder because
  the API currently running on 5251 holds its default build files.
- `dart analyze lib` passed with no issues after the Passenger error-state
  cleanup.

## Not verified or incomplete

- Recheck on 24 October: no local listener or `dotnet` process was visible on
  ports 5251 or 5252. Docker CLI access to the Docker Desktop named pipe was
  denied, and direct socket checks to 55432/5251/5252 were blocked by Windows
  socket permissions. This session therefore did not confirm current
  PostgreSQL/API runtime health or run database-backed Driver requests. No
  API process was stopped.
- The current Driver configuration was confirmed in source: build-time defines
  select role `Driver`, driver ID `17`, and API URL `http://127.0.0.1:5251`;
  the development authentication handler accepts the matching headers only
  for loopback requests. The existing Driver screen calls the assigned-trip,
  start/end, delay, and Nearly Full endpoints.
- `dart analyze lib` passed with no issues, and the API source build passed
  with zero warnings and errors. A fresh Driver APK was not built: Flutter
  exited because it could not create `C:\flutter\bin\cache\lockfile` under
  the SDK directory. A narrowly scoped write-access request for the Flutter
  cache was not granted. ADB also could not connect to its local daemon, so
  the existing Passenger app could not be switched or observed in this run.
- The Driver screen explicitly says that device GPS sending is not connected.
  No GPS, SignalR event, start/end action, or notification behavior was
  exercised in this run.

- At the previous review, the API process on 5251 was older than the current
  source and returned HTTP 404 for `GET /api/trips/assigned`; the current-source
  instance on 5252 had that endpoint. In the 24 October recheck, neither port
  had a visible listener, so there was no API process to replace.
- Starting and ending a trip from the Flutter Driver screen were not tested.
  Building/switching the app to Driver mode could not be completed because
  `flutter.bat --version` hung without output in this shell. The already-built
  Passenger APK ran; this does not verify a fresh Android build.
- Actual Driver phone GPS submission is not connected. The app does not create
  simulated GPS coordinates. Admin active-trip map, broader driver issue
  reports, and Driver/Admin messaging remain incomplete.
- SignalR location delivery, a real GPS-to-map flow, and notification read-state
  changes were not exercised on the emulator in this review. The inbox was
  verified in its empty state only.
- Development header authentication is not real sign-in and must not be used
  outside local development.

## Safe next steps before PR2

1. In normal Windows PowerShell, confirm PostgreSQL is healthy on host port
   55432 and run the current API source on 5251 without applying migrations.
2. Run Flutter from a normal PowerShell session if the Flutter CLI remains
   blocked here, then validate the Driver flavor with driver ID 17.
3. Demonstrate Driver start/end using a disposable scheduled demo trip. Avoid
   starting the currently retained demo trip unless its completed state is
   wanted in the shared database.
4. Record actual GPS/SignalR, delay/cancellation inbox, and mark-as-read results
   separately; update the Gantt progress fields to match demonstrated work.
