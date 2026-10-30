# UWAY — University Transportation System

UWAY is the University of Sharjah Senior Project (College of Computing and Informatics, Fall 2026/2027): an advanced prototype that gives passengers real-time transportation information and gives drivers and administrators the tools to run university bus trips. The Senior Project replaces the Junior Project's reservation and QR-boarding process with **Trip Intent** (a passenger tells the system which trip they plan to take), live tracking, notifications, and operations management.

> **Status (end of October 2026).** Phase 3 (core development) is complete and Phase 4 (real-time and operations) is largely complete. The system is a working prototype used with test data. See [Known limitations](#known-limitations) and [docs/verification-status.md](docs/verification-status.md).

## What the system does

| Role | Main capabilities |
| --- | --- |
| **Passenger** (mobile app) | Search trips by direction, route and departure time; view trip details and route stops; **"I'm Taking This Trip"** and cancel it; choose and change a drop-off stop (also by tapping a stop on the map); follow the bus live on a map; receive in-app notifications; see the trips with an active Trip Intent; send reports with photos or videos and read the administration's reply. |
| **Driver** (mobile app) | See assigned trips; start and end a trip; share GPS location during the trip; report a delay; send **Bus Nearly Full**; see how many passengers joined; send reports with attachments and read replies. |
| **Admin** (web dashboard) | Manage stops, routes, buses, drivers and trips (create, edit, cancel with a reason, restore, delete); monitor active trips on a live map with Expected Riders and capacity status; **Call Driver**; notification bell; review and answer passenger and driver reports; university-stop source map. |

Passengers only see trips for their own audience (**Men** or **Women**). Campus stops reserved for one audience (UOS – M3 for men, UOS – W3 for women) are hidden from trips of the other audience.

Trip Intent is **not** a reservation and does not hold a seat.

## Technology

| Area | Technology |
| --- | --- |
| Mobile app | Flutter / Dart (one app, Passenger and Driver roles), `flutter_map` with OpenStreetMap tiles, `geolocator`, `signalr_core` |
| Admin dashboard | React + JavaScript (Vite), Leaflet |
| API | ASP.NET Core 9 Web API, Entity Framework Core (Npgsql), SignalR |
| Database | PostgreSQL 17 (Docker), versioned EF Core migrations |

```text
UWAY/
├── admin/                 React + Vite admin dashboard
├── backend/UWAY.Api/      ASP.NET Core API, SignalR hub, EF Core model and migrations
├── database/              Local PostgreSQL (Docker Compose)
├── docs/                  Architecture, setup, frontend and verification notes
├── mobile/                Flutter app (Passenger and Driver)
├── UWAY-Prototype/        Interface prototype from the earlier phase
├── UWAY_stops_coordinates.geojson / ..._import_review.csv / ..._Audit.xlsx
│                          University City stop data collected by the team
├── NuGet.Config
└── UWAY.sln
```

## Requirements

- Git
- .NET 9 SDK
- Node.js 20+ and npm
- Flutter SDK, and Android platform tools (`adb`) for a physical phone
- Docker Desktop (local PostgreSQL)

## Quick start (Windows PowerShell)

Run each part in its own PowerShell window from the project root.

**1. Database**

```powershell
cd database
copy .env.example .env          # then set POSTGRES_PASSWORD in database\.env
docker compose up -d --wait
```

**2. API environment (in the window that runs the API)**

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:ConnectionStrings__UwayDatabase = "Host=localhost;Port=55432;Database=uway;Username=uway_app;Password=<password from database\.env>"
```

**3. First-time data setup (stop the API first; run in this order)**

```powershell
dotnet run --project backend/UWAY.Api -- --migrate
dotnet run --project backend/UWAY.Api -- --import-source-stops
dotnet run --project backend/UWAY.Api -- --seed-source-routes
dotnet run --project backend/UWAY.Api -- --seed-test-users
```

**4. Run the API**

```powershell
dotnet run --project backend/UWAY.Api --urls http://0.0.0.0:5251
```

The API listens on port `5251`. `GET /health` reports whether PostgreSQL is reachable.

**5. Run the Admin dashboard**

```powershell
cd admin
npm install
npm run dev
```

Open `http://localhost:5173` and sign in with an Admin account. Set `VITE_UWAY_API_URL` if the API uses another address.

**6. Run the mobile app on an Android phone**

```powershell
cd mobile
adb reverse tcp:5251 tcp:5251
flutter pub get
flutter run
```

`adb reverse` lets the phone reach the API on the PC as `127.0.0.1:5251`. Use `--dart-define=UWAY_API_URL=http://<address>:5251` to point the app at a different API address. For a smoother map during demos use `flutter run --profile`; debug builds are noticeably slower.

## Test accounts

Created by `--seed-test-users` (Development only). **These accounts and the shared password are for local testing only.**

| Role | Email |
| --- | --- |
| Admin | `admin@uway.test` |
| Passenger (men) | `omar.hassan@uway.test`, `khalid.saeed@uway.test` |
| Passenger (women) | `mariam.ali@uway.test`, `noura.salem@uway.test` |
| Driver | `driver<ID>@uway.test`, one per active driver (for example `driver1@uway.test`) |

The password for every test account is `Uway@2026`. Run `--seed-test-users` again after adding drivers so that they receive accounts.

## Command-line options of the API

Run with `dotnet run --project backend/UWAY.Api -- <option>`. Data commands exit when finished and are limited to the Development environment.

| Option | Purpose |
| --- | --- |
| `--migrate` | Apply pending database migrations. Normal API startup never changes the schema. |
| `--list-migrations` | List the migrations known to the API. |
| `--migration-status` | Show applied migrations, required tables and model drift without changing anything. |
| `--import-source-stops` | Insert the missing stops from the university source GeoJSON (insert-only). |
| `--seed-source-routes` | Create or update the routes `KF-IN`, `KF-OUT`, `HRH-IN`, `HRH-OUT` from the imported stops. |
| `--seed-test-users` | Create the test accounts above. |
| `--remove-demo-routes` | Preview the demonstration routes and trips that would be removed. Add `--confirm` to delete them. The four main routes, buses, drivers, stops and accounts are never touched. |

## Roles and access

Every request after login carries a signed bearer token (HMAC-SHA256, valid for 12 hours). Passwords are stored as salted PBKDF2 hashes. Endpoints are protected by role policies: Passenger, Driver and Admin.

| Action | Who |
| --- | --- |
| Manage routes, stops, buses, drivers; create, edit, cancel, restore, delete trips; list a trip's joined passengers; update report status | Admin |
| Start or end a trip | The assigned Driver, or an Admin |
| Report a delay | The assigned Driver, or an Admin |
| Send GPS location; send Bus Nearly Full | The assigned Driver only |
| Browse trips, create and cancel Trip Intent, choose a drop-off stop | Passenger |
| Read the latest location of a started trip | Admin, the assigned Driver, any Passenger who may view the trip |
| Send reports with attachments | Passenger or Driver |

Outside Development, set `Uway:TokenKey` to a random secret of at least 32 characters. Optional loopback-only development headers exist for local API testing (`Uway:EnableDevelopmentHeaderAuthentication=true`); they are not used by the apps and must never be enabled in deployment.

## Main API areas

| Area | Endpoints |
| --- | --- |
| Authentication | `POST /api/auth/login`, `GET /api/auth/me` |
| Trips | `GET/POST /api/trips`, `GET /api/trips/assigned`, `GET/PUT/DELETE /api/trips/{id}`, `POST /api/trips/{id}/start`, `/end`, `/delay`, `/cancel`, `/restore`, `GET /api/trips/{id}/passengers` |
| Trip Intent | `POST/GET/DELETE /api/trips/{tripId}/intent`, `PUT /api/trips/{tripId}/intent/drop-off` |
| Capacity | `GET /api/trips/{tripId}/capacity`, `POST /api/trips/{tripId}/nearly-full` |
| Live location | `POST/GET /api/trips/{tripId}/location`; SignalR hub `/hubs/trip-locations` (`JoinTrip`, `LeaveTrip`, `LocationUpdated`) |
| Routes, stops, fleet | `/api/routes`, `/api/stops`, `/api/buses`, `/api/drivers` |
| Notifications | `GET /api/notifications`, `GET /api/notifications/unread-count`, `PUT /api/notifications/{id}/read`, `PUT /api/notifications/read-all` |
| Reports | `POST /api/reports`, `GET /api/reports/mine`, `GET /api/reports` (Admin), `PUT /api/reports/{id}` (Admin), `POST /api/reports/{id}/attachments`, `GET /api/reports/attachments/{id}` |

### Trip lifecycle

A trip has one of three statuses: `Scheduled`, `Started`, `Finished`. A **delay** and a **cancellation** are alerts carried by `delayMinutes` and `cancelledAtUtc`; they are not statuses.

| Status | Meaning |
| --- | --- |
| `Scheduled` | Created and awaiting operation. Can be started, delayed or cancelled; a cancelled trip can be restored by an Admin. |
| `Started` | The trip is in progress. Can be ended; GPS locations are accepted only in this state. |
| `Finished` | Terminal state. |

Invalid transitions return HTTP 409. Updates carry a concurrency version so two simultaneous changes cannot both win silently.

### Trip Intent, capacity and notifications

- A Trip Intent records one drop-off stop. The API checks that the stop belongs to the trip's route and is allowed for the trip's audience. The mobile app additionally limits the choices by trip direction (campus stops for trips to the campus, route stops for trips from the campus), inferring the direction from stop names. The API does not check the direction yet.
- **Expected Riders** is the number of active intents. Capacity status compares it with the assigned bus: below 80% `Normal`, from 80% `NearlyFull`, equal `Full`, above `OverCapacity`. The assigned Driver can also send a Bus Nearly Full report.
- **Notifications** are stored in PostgreSQL. Passengers with an active intent receive trip started, delayed, cancelled, completed, reinstated, and *bus approaching your drop-off stop* (within 500 meters of the selected stop) notifications. Drivers and Admins receive notifications such as trip assignment changes, Bus Nearly Full, and new or updated reports. Duplicates are prevented by a unique key. Notifications are delivered inside the apps (refreshed automatically); push notifications are not implemented.
- **Live location:** only the latest point is stored on the trip row. The API saves it, then publishes `LocationUpdated` through SignalR. Clients can reload the latest point with REST after reconnecting.

### Reports

Passengers and Drivers can send a report (category, optional trip, description of at least five characters) with up to five attachments: images up to 10 MB and videos up to 30 MB, stored in the database and readable only by the owner and Admins. Admins set the status (`Open`, `InReview`, `Resolved`) and write a response, which notifies the sender.

## University City stops and routes

The team collected the University City stops with coordinates into an 86-point dataset (`admin/public/data/UWAY_stops_coordinates.geojson`, shown on the Admin *Source map*). `--import-source-stops` inserts missing stops using a stable key (a SHA-256 digest of group, name and rounded coordinates). `--seed-source-routes` then creates one inbound (to the campus) and one outbound (from the campus) route for each of two lines (King Faisal and Al Heerah). The stop order follows the order of the collected data and is **pending confirmation by the University City**; the map draws straight segments between stops, not the real road geometry.

## Known limitations

- Accounts are local test accounts; there is no registration, password reset, or integration with the University's authentication system. The mobile session is kept in memory only, and a deactivated user's token stays valid until it expires.
- No push notifications (FCM); notifications are in-app only.
- No emergency alerts and no two-way Driver–Admin chat. Driver–Admin communication uses reports, notifications and **Call Driver**.
- Your Trips lists trips with an active Trip Intent only; there is no trip history yet.
- A passenger can still select a stop the bus has already passed.
- The API does not validate the drop-off stop against the trip direction (the app does).
- The route line is not the real road path; the University City's route data has not been received yet.
- English only; Arabic/RTL translation and a full Account page are planned.
- The university logo (`mobile/assets/uos-logo.png`) has not been added; campus stops use an icon.
- Tests: Flutter widget and unit tests exist for the mobile app; the backend has no automated tests yet. Behavior with many simultaneous users has not been measured.

## More documentation

- [Architecture and design decisions](docs/architecture.md)
- [Setup and operations guide](docs/phase-2-setup.md)
- [Frontend status](docs/frontend-status.md)
- [Verification status](docs/verification-status.md)
- [Mobile app notes](mobile/README.md) and [database notes](database/README.md)
