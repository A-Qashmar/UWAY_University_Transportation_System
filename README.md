# UWAY — Smart University Transportation System

"UWAY - Smart University Transportation System - Senior Project UoS"

UWAY is the University of Sharjah Senior Project advanced prototype. It provides passenger transportation information and supports driver and administrator operations. The Senior Project explicitly excludes reservations and QR-based boarding.

## Current implementation

The Passenger and Driver experiences live in one Flutter app. The Admin dashboard uses React and JavaScript. The API uses ASP.NET Core 9 and Entity Framework Core with PostgreSQL. The backend provides database health checks, route/stop/fleet management, scheduled-trip management, protected trip lifecycle operations, passenger Trip Intent with drop-off selection, rule-based capacity monitoring, latest bus location tracking, and a persisted passenger notification inbox. The Admin web app now includes record editing, trip cancellation, search/filter controls, the retained source-stop map, and an active-trip monitor that reads saved locations and capacity from the API. The Driver app includes assigned-trip operations and foreground device GPS submission. These latest frontend changes have not yet completed a Flutter dependency resolution/build or a live end-to-end check.

```text
UWAY/
├── admin/                 React + Vite admin shell
├── backend/UWAY.Api/      ASP.NET Core API, health endpoint, DB context
├── database/              Local PostgreSQL container setup
├── docs/                  Architecture and Phase 2 notes
├── mobile/                Single Flutter app with Passenger and Driver areas
├── UWAY-Prototype/        Existing interface prototype files
├── .gitignore
└── UWAY.sln
```

## Requirements

- Git
- .NET 9 SDK
- Node.js 20+ and npm
- Flutter SDK
- Docker Desktop (needed to run local PostgreSQL)

## Start the database

From the project root, copy `database/.env.example` to `database/.env` and set a local password. Start PostgreSQL from `database/` with `docker compose up -d --wait`. Set `ConnectionStrings__UwayDatabase` in the PowerShell session running the API, using that same password. The database stays bound to localhost.

Apply pending schema migrations with `dotnet run --project backend/UWAY.Api -- --migrate`, then start the API with `dotnet run --project backend/UWAY.Api`. Use `--list-migrations` to see the migrations known to the API. Normal API startup does not change the schema. Never commit `database/.env` or real credentials.

Use `dotnet run --project backend/UWAY.Api -- --migration-status` to inspect applied migrations, required tables, and model drift without changing the schema.

## Run the API

```powershell
dotnet restore UWAY.sln
dotnet run --project backend/UWAY.Api
```

The API health endpoint is `/health`; it reports unhealthy until PostgreSQL is reachable and does not require login. Route, stop, bus, and driver management endpoints require the `Admin` role. Trip creation/deletion and cancellation remain Admin-only; trip start/end requires the assigned `Driver`, and delay requires the assigned `Driver` or `Admin`.

No real identity provider is connected yet. Without one, protected API routes fail closed with HTTP 401. For local loopback development only, a clearly non-production header identity can be enabled with `$env:Uway__EnableDevelopmentHeaderAuthentication = 'true'` while running the API in `Development`. Send `X-Uway-Dev-Role: Admin` for admin work, `X-Uway-Dev-Role: Driver` and `X-Uway-Dev-DriverId: <driver-id>` for driver work, or `X-Uway-Dev-Role: Passenger` and optionally `X-Uway-Dev-UserId: <local-passenger-id>` for passenger work. The optional user ID lets local tests act as different passengers. These headers are only a local test aid; they are not login or production authorization. Replace them with the university-approved identity provider before deployment.

Trip lifecycle endpoints are `POST /api/trips/{id}/start`, `/end`, `/delay`, and `/cancel`. A scheduled, uncancelled trip can start; only a started trip can end. Delay requires positive `delayMinutes` and a reason. Cancellation requires an admin reason and retains associated trip intent records. Invalid state transitions return HTTP 409. Changes carry a concurrency version so two simultaneous updates cannot both silently win.

A trip's status is only one of three lifecycle values. A delay or a cancellation is a simple alert carried by `delayMinutes` / `cancelledAtUtc`, not a status.

| Status | Meaning and allowed lifecycle actions |
| --- | --- |
| `Scheduled` | Created and awaiting operation; can start, be delayed (alert), or be cancelled (alert). |
| `Started` | Driver has started the trip; can be ended by the assigned driver or cancelled by an admin (alert). |
| `Finished` | Driver ended the trip; terminal state. |

| Alert | Where it lives |
| --- | --- |
| Delay | `delayMinutes` > 0 with `delayReason`; the trip keeps its status. |
| Cancellation | `cancelledAtUtc` with `cancellationReason`; the trip keeps its status, cannot start, accept new intents or be cancelled again. Existing trip intent records remain attached. |

Migration `20261026140000_TripStatusLifecycle` converts existing rows: `InProgress` to `Started`, `Completed` to `Finished`, `Delayed` to `Scheduled` (the delay minutes stay), and `Cancelled` to `Scheduled` (or `Started` if it had started; the cancellation timestamp stays). Its `Down` reverses this.

Starting and ending require a `Driver` role and the authenticated identity's `uway_driver_id` claim to match the trip assignment. Delay is allowed to the assigned driver or an admin; cancellation is admin-only. The actual identity provider must issue these roles and the driver ID claim. The development headers above only help local loopback testing and must not be used as a substitute for real sign-in.

Passengers can use the existing `GET /api/trips` and `GET /api/trips/{id}` endpoints to browse trips and view route/trip details. Passenger list results include `Scheduled` and `Started` trips (including delayed or cancelled ones) and `Finished` trips from the last 14 days, so a passenger can still report a problem about a recent trip. Passenger responses omit driver, bus, and internal assignment identifiers. Drivers retain assigned-trip checks on details; Admins retain access to the full list and all trip details. These read permissions do not grant access to trip mutations, fleet/route writes, driver location submissions, capacity reports, or another passenger's intent/notifications. Route and stop GETs and live-location reads already allow authenticated Passengers; their write actions remain Admin-only. Development header authentication is local-only and is not production sign-in.

## Passenger Trip Intent and drop-off

Trip Intent records that a passenger plans to take a trip. It is not a reservation and does not hold a seat. Each active intent includes one drop-off stop on that trip's route. New intents are accepted while a trip is `Scheduled` and not cancelled; an existing passenger can change the stop while it is `Scheduled` or `Started` and not cancelled. Intents cannot be added to cancelled or finished trips, and drop-off selection cannot be changed after a trip ends.

All of these routes require the `Passenger` role and use the authenticated subject as the passenger identity:

| Method and endpoint | Purpose |
| --- | --- |
| `POST /api/trips/{tripId}/intent` | Create an active intent. JSON body: `{"dropOffStopId": 12}`. The stop must belong to the trip's route. |
| `GET /api/trips/{tripId}/intent` | Read the caller's active intent. |
| `PUT /api/trips/{tripId}/intent/drop-off` | Change the caller's drop-off stop. JSON body: `{"dropOffStopId": 14}`. |
| `DELETE /api/trips/{tripId}/intent` | Cancel the caller's active intent. |

Successful create, read, and update responses include `expectedRiderCount`, calculated from uncancelled intents. Cancellation returns the new count. A database unique index prevents more than one active intent for a passenger and trip; cancelling preserves the record and permits a later new intent. Active intents determine expected rider count and passenger-specific notification eligibility. They are not required to view live bus location. Invalid route stops return HTTP 400, duplicate active intents return HTTP 409, and invalid trip states return HTTP 409.

## Capacity monitoring and Driver report

`GET /api/trips/{tripId}/capacity` returns the trip's active `expectedRiderCount`, assigned bus capacity, capacity status, and any Driver report timestamp/identity. Admins and the assigned driver can read it for scheduled, delayed, or in-progress trips. An active bus assignment is required. Terminal trips return HTTP 409.

The rule uses active Trip Intent count; it does not represent confirmed boardings. A count below 80% of bus capacity is `Normal`. At 80% or more and below capacity it is `NearlyFull`. A count equal to capacity is `Full`; a count above capacity is `OverCapacity`. The assigned driver can also send `POST /api/trips/{tripId}/nearly-full`, without a request body, while the trip is `Started`. This records the first report time and driver ID; the report makes status at least `NearlyFull` unless count-based `Full` or `OverCapacity` takes precedence. Later duplicate reports do not replace the original timestamp.

The near-full report is available only to the assigned `Driver`; passengers and admins receive HTTP 403. Capacity reads allow Admin or the assigned Driver. Missing or inactive buses and invalid report states return HTTP 409. The persisted report is available through the capacity response for the Admin dashboard. It is an operational report, not a reservation or boarding confirmation.

## Live bus location

The assigned Driver sends a GPS point with `POST /api/trips/{tripId}/location`, using JSON such as `{"latitude": 25.2048, "longitude": 55.2708}`. The trip must be `Started` and have an active assigned bus. Coordinates are validated (latitude -90 through 90, longitude -180 through 180). The API supplies the UTC receive timestamp; clients do not choose or backdate it. The response includes the trip ID, coordinates, and timestamp.

`GET /api/trips/{tripId}/location` returns the latest point while the trip is in progress. It is available to Admins, the assigned Driver, and any authenticated Passenger allowed to view the trip, regardless of Trip Intent status. An authorized read before the first driver update returns HTTP 204. Requests with invalid coordinates return HTTP 400, unauthorized roles return HTTP 403 (or HTTP 401 when no local development identity is supplied), and inactive trip states or a missing/inactive bus return HTTP 409.

Only the latest location is stored on the trip row; this milestone does not keep a GPS trail or simulate movement. Clients connect to `/hubs/trip-locations`, invoke `JoinTrip(tripId)`, and listen for `LocationUpdated`. Any authenticated Passenger allowed to view an active trip may join, whether or not they have a Trip Intent. The assigned Driver may join only their trip, and an Admin may join an active trip. The REST location endpoint saves first, then sends the event to subscribed Admin/Driver connections and all subscribed Passengers in the trip's passenger group. Trip Intent remains separate and is used for expected rider count and trip-specific notifications, such as delay/cancellation and selected-stop alerts. Invalid updates are not published, and location updates stop when the trip is completed or cancelled. Call `LeaveTrip(tripId)` to stop a client subscription. SignalR delivery is in-memory and best-effort; clients can use the REST GET endpoint to reload the latest saved location after reconnecting. The Admin live operations map reads current active trip locations and capacity every 15 seconds. The Passenger tracking screen now displays the latest REST/SignalR location on an OpenStreetMap-based map. The Driver app source now requests foreground device location permission and posts real GPS points while an active trip's location-sharing control is on. Flutter build and live phone GPS delivery still need verification after dependencies are available. Authentication is still development-only: protected access uses the existing loopback header mechanism and must be replaced with real sign-in before deployment.

## Passenger notifications

Notifications are persisted in PostgreSQL as an inbox entry linked to the Trip Intent that qualified the passenger. Only active Trip Intents receive trip-specific entries; cancelling an intent stops eligibility for later notifications. Existing entries remain in the passenger's inbox as history. Trip Intent remains an expression of intent, not a reservation. Live location authorization is independent of this notification rule.

| Method and endpoint | Purpose |
| --- | --- |
| `GET /api/notifications?take=50` | Return up to 100 of the authenticated Passenger's most recent notifications. |
| `PUT /api/notifications/{notificationId}/read` | Mark one of the caller's notifications as read; another passenger's ID returns 404. |

The API creates notifications for trip start, delay, cancellation, and completion. Repeating the same delay and reason does not add a duplicate for the same intent; a materially different delay can create a new entry. An accepted Driver location update also checks each active intent's selected drop-off stop. If that stop belongs to the trip route, has coordinates, and is within 500 meters of the actual bus location, the passenger gets one `BusApproachingDropOff` entry for that intent and stop. Repeated GPS points do not repeat it. Missing stop coordinates produce no approach notification. No GPS or notification trigger is simulated. Push services are not implemented. The Passenger inbox empty state was observed on Android; notification delivery and mark-as-read were not exercised there. The React notification UI remains future work.

Notification retrieval requires the `Passenger` role and returns only the caller's inbox. The existing development header identity is for local testing only and is not production authentication.

## Run the Admin dashboard

```powershell
cd admin
npm install
npm run dev
```

The Admin page calls the existing API on port `5251` and uses local development
headers. It is a local academic prototype, not a production login. Set
`VITE_UWAY_API_URL` when the API uses a different local URL.

## Run the mobile app

```powershell
cd mobile
flutter pub get
flutter run
```

To run the Driver workflow locally, use the driver's ID shown in the Admin
dashboard after creating a driver:

```powershell
adb reverse tcp:5251 tcp:5251
flutter run --dart-define=UWAY_DEV_ROLE=Driver --dart-define=UWAY_DEV_DRIVER_ID=1 --dart-define=UWAY_API_URL=http://127.0.0.1:5251
```

## Scope boundary

The current project includes database connectivity, fleet/route management, scheduled trips and lifecycle operations, passenger Trip Intent with drop-off selection, rule-based capacity status with a Driver near-full report, latest bus location APIs, SignalR location delivery, and persisted Passenger notification retrieval. Admin can manage stops, routes, buses, and drivers, create and cancel trips, inspect the source map, and monitor active locations and capacity. Driver can list assigned trips, start/end, report delays and near-full, and start foreground GPS sharing. Passenger can browse trips, set/cancel Trip Intent, follow the live location map, and use the notification inbox. Real login/registration, Passenger trip history, report intake/attachments, emergency alerts, Driver/Admin messaging, push delivery, and an Admin notification inbox are not provided by the current API. The current Admin map polls the saved latest point; Passenger location continues to use SignalR. See [the frontend status](docs/frontend-status.md), [architecture note](docs/architecture.md), and [Phase 2 setup guide](docs/phase-2-setup.md).

### University City source stops

The Admin Source Map displays the 86 points from `admin/public/data/UWAY_stops_coordinates.geojson`. Import preparation adds nullable `SourceGroup` and `SourceKey` metadata to `stops`; existing UWAY stops remain unchanged and untagged. The key is a SHA-256 digest of source group, original source name, and coordinates rounded to the database's six decimal places, so identical names at different locations remain distinct. API responses add nullable `sourceGroup`; existing stop request bodies do not need to change.

An explicit Development-only importer is prepared but has not been run. It inserts only missing source keys, skips exact existing manual-stop matches, and never edits/deletes stops or creates `route_stops`. It reports valid, added, pre-existing, duplicate, and invalid feature counts. The API build copies the source GeoJSON to its output/publish directory and prefers `data/source-map/UWAY_stops_coordinates.geojson`, with the current root file and Admin map copy as fallbacks. Before a future demo import, review/apply the pending `StopSourceIdentity` migration only with approval, then run `dotnet run --project backend/UWAY.Api -- --import-source-stops` from the repository root with the Development database configuration. The source `source_order` is descriptive and is not used to build route order.

## Women's and men's trips

Every trip has an audience: `F` (women) or `M` (men), chosen by the Admin when the trip is created. Passengers have a profile in the `passengers` table (`Id`, `Email`, `FullName`, `Gender` of `F` or `M`) and only see, open, join and track trips for their own gender. A signed-in account with no passenger profile gets a 403 instead of a trip list. Migration `20261027120000_PassengerGenderAndTripAudience` adds the column and table and two fake test passengers (`test-female-1`, `test-male-1`). Trips created before the migration have no audience and are hidden from passengers until they are recreated. For local API testing, run the app with `--dart-define=UWAY_DEV_PASSENGER_ID=test-female-1` (the default is `test-male-1`). In Demo Data mode use `--dart-define=UWAY_DEMO_GENDER=F` to see the women's sample trips. A real login that reads the gender from the profile is still to be built.

## Sign-in and test accounts

Everyone signs in with an email and password (`POST /api/auth/login`). The account decides the role; a passenger's gender (F or M) comes from the passenger profile, so passengers only see their own gender's trips. Sessions are signed tokens that last 12 hours. Passwords are stored as PBKDF2 hashes in the `users` table.

Create the local test accounts (Development only):

```powershell
dotnet run --project backend\UWAY.Api -- --migrate
dotnet run --project backend\UWAY.Api -- --seed-test-users
```

The password for every test account is `Uway@2026`.

| Role | Email |
| --- | --- |
| Admin | admin@uway.test |
| Passenger (man) | omar.hassan@uway.test, khalid.saeed@uway.test |
| Passenger (woman) | mariam.ali@uway.test, noura.salem@uway.test |
| Driver | driver&lt;ID&gt;@uway.test, one per active driver (for example driver1@uway.test) |

Outside Development set `Uway:TokenKey` to a random secret of at least 32 characters. The old development headers still work only when `Uway:EnableDevelopmentHeaderAuthentication=true` in Development.

## Cleaning demo data and driver-app assets

- Preview unofficial (demo) routes and their trips: `dotnet run --project backend\UWAY.Api -- --remove-demo-routes`
- Delete them: add `--confirm`. Official routes (KF-IN/OUT, HRH-IN/OUT), buses, drivers, stops and accounts are never touched. Development only.
- Put the University of Sharjah logo at `mobile/assets/uos-logo.png` (used on campus stops).
- After pulling these changes run `--migrate` and `--seed-test-users` again (new drivers get accounts).
