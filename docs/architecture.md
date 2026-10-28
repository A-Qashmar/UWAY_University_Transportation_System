# UWAY Architecture and Phase 2 Decisions

## System shape

The solution has three clients/components: one Flutter mobile application with Passenger and Driver areas, a React and JavaScript Admin web client, and an ASP.NET Core Web API backed by PostgreSQL. Clients communicate with the API over HTTP. The API provides role policies for Passenger, Driver, and Admin access as a starting point for later identity work.

## University City source-stop identity

The Admin Source Map reads the supplied 86-point GeoJSON from the Admin static assets. Its source groups remain metadata labels; they are not treated as UWAY routes, and the source order is not used as a route sequence. The prepared additive `StopSourceIdentity` migration introduces nullable `SourceGroup` (80 characters) and nullable `SourceKey` (64-character SHA-256 hex) columns plus a unique index on `SourceKey`. Existing Stop rows retain their names, coordinates, activation state, route associations, and null source metadata. PostgreSQL permits multiple null values in this unique index.

The stable key is computed from the trimmed source group, original `source_name`, and latitude/longitude rounded to six decimal places using invariant formatting. Thus two same-name points at different coordinates do not collide. The API response adds a nullable `sourceGroup` field only; request contracts remain unchanged, so existing clients can ignore the extra response field and cannot erase source metadata in normal Stop updates.

`SourceStopImporter` is invoked only through the explicit Development-only `--import-source-stops` command and requires the metadata migration to already be applied. It parses each GeoJSON feature, counts invalid and duplicate entries, inserts keys not already present, skips exact name/coordinate matches to untagged manual Stops, and does not update or delete any row. It creates no route or `route_stops` relationships. The API project packages the source file under `source-map/` for both build and publish output, preferring `data/source-map/` and falling back to the source file currently at the repository root or the Admin static copy. The command and migration have been prepared but neither was run or applied to the current database.

## Decisions for the setup phase

| Area | Setup choice | Phase 2 boundary |
| --- | --- | --- |
| Mobile | Flutter/Dart, one app for Passenger and Driver | Passenger list/details, intent/drop-off, location, and inbox; Driver assigned-trip list and lifecycle/delay/capacity actions; Passenger browsing and intent flow observed on Android; Driver flavor still needs a fresh build |
| Admin | React + JavaScript with Vite | Local dashboard has stop/route/fleet/trip forms; trip form created a scheduled trip in the browser and it was removed through the guarded API; real authentication and active-trip map remain future work |
| Backend | ASP.NET Core 9 Web API | Database health, route/stop/fleet CRUD, trip lifecycle, passenger Trip Intent/drop-off, capacity, location, and notification inbox endpoints |
| Database | PostgreSQL with EF Core/Npgsql | Schema covers routes, stops, buses, drivers, trips, Trip Intents, and persisted Trip Notifications; trip rows hold the latest GPS point and timestamp plus capacity reports; migrations are applied explicitly |
| Authentication | Role authorization policies for Passenger, Driver, Admin | No identity provider or login yet; protected routes fail closed; optional loopback-only development headers are not production auth |
| Realtime location | ASP.NET Core SignalR hub | Trip location delivery is implemented; client UI and reconnect handling remain future work |
| Passenger notifications | Scoped notification service and passenger inbox API | Trip events and actual GPS proximity checks create deduplicated records; Passenger inbox empty state observed on Android, delivery/read-state checks remain |
| Push and maps | Future integration points | FCM and Google Maps/Mapbox remain out of setup |

## Scope source

Progress Report #1 sets the Senior Project direction: passenger trip information and trip intent, live tracking after trip start, drop-off selection, notifications, Driver operations and communication, and Admin management. It explicitly removes reservation and QR boarding from the Senior Project. The current backend includes route/stop/fleet management, trip lifecycle operations, passenger Trip Intent with route-validated drop-off selection, rule-based capacity monitoring, and live location updates. Capacity uses uncancelled intent count against assigned bus capacity, with an 80% near-full threshold and a persistent Driver report. Trip Intent remains an expression of intent, not boarding evidence.

## Live location decision

The tracking foundation stores one latest latitude/longitude and the server receive timestamp on the trip row. The current requirements need passengers and Admins to see the bus's current position; they do not require route replay, location analytics, or an audit trail. This avoids a separate high-volume history table while keeping a clear path to add one if later requirements need it. The assigned Driver can update location only during an in-progress trip with an active bus. Admins and the assigned Driver can read the latest point; any authorized Passenger can read it without an active Trip Intent. The SignalR hub at `/hubs/trip-locations` authorizes each `JoinTrip` request and adds the connection to a trip-scoped group. Passenger connections use a shared passenger group for that trip; Trip Intent does not gate location access or delivery. The REST publisher saves to PostgreSQL first, checks the trip is still active, and then publishes `LocationUpdated` to Admin/Driver and Passenger groups. Active Trip Intents continue to determine expected rider count and will be used separately for passenger-specific notification eligibility. SignalR is a live delivery layer, not a persistence layer; reconnecting clients can reload the latest stored point with REST. Coordinates are range checked both at the API boundary and by PostgreSQL constraints. The UTC timestamp is supplied by the API when it receives the update.

The development header authentication remains enabled only for local loopback testing when explicitly configured in Development. It is not production authentication; role and driver claims must later come from a real identity provider. Hub groups and the in-memory SignalR connection lifetime are not durable; clients should reload the latest point after reconnecting. No simulated GPS data is generated.

## Passenger trip reads

The existing trip read actions provide the Passenger app's browsing foundation. `GET /api/trips` permits Admins and Passengers; an Admin receives the full ordered list, while a Passenger receives Scheduled and Started trips plus Finished trips from the last 14 days (delays and cancellations are alerts, not statuses). `GET /api/trips/{id}` permits Admins, Passengers, and Drivers; Passengers can read any trip, Drivers remain restricted to their assigned trip, and Admins retain full read access. Passenger responses omit driver, bus, and internal assignment identifiers. These policies do not affect trip creation/deletion or lifecycle actions. Route/stop writes, bus/driver management, location submission, capacity reporting, and passenger-owned intent/notification boundaries remain unchanged.

The Admin page uses local development headers and the existing Admin CRUD APIs to create, edit, and delete stops, routes, buses, and drivers. A route's stop checkbox selection order becomes its route order. Trips are created with a route, bus, driver, and UTC departure time. The Admin can cancel a trip with a recorded reason; the API has no trip edit/reassignment endpoint, so the web app does not offer one. The live operations page reads each in-progress trip's latest GPS and capacity and refreshes every 15 seconds. It displays only coordinates returned by the API and does not simulate movement. The `GET /api/trips/assigned` action is Driver-only and returns trips assigned to the authenticated driver ID. The Flutter Driver screen uses it for trip selection, start/end, delay and nearly-full actions, plus an opt-in foreground GPS stream that sends valid points through the existing location endpoint. GPS sharing stops when the driver disables it, the screen is disposed, or the location request fails.

## Frontend boundaries

The Passenger app reuses `GET /api/trips`, trip and route reads, Trip Intent/drop-off operations, the existing latest-location REST endpoint plus SignalR hub, and the Passenger notification inbox. The map uses OpenStreetMap tiles and includes attribution. Passenger Trip Intent remains optional for location viewing and is only used for expected riders and notification eligibility.

The Driver app is a local role-selected build. It has assigned trips, route stops, lifecycle actions, delay reporting, the nearly-full report, and foreground device GPS. It does not request background location. The Admin web client uses existing CRUD endpoints and does not introduce API operations.

Authentication is not connected to a university identity provider. No client login or registration screen claims to create an account; current local development headers are only a test mechanism and production APIs fail closed without a configured identity. The API also has no Passenger history endpoint, general report or attachment endpoints, emergency alert endpoint, driver-admin messaging API, or Admin notification inbox. The clients identify these missing capabilities instead of presenting nonfunctional actions. No database changes were made for this frontend work.

## Notification inbox and eligibility

Trip lifecycle controllers queue `TripStarted`, `TripDelayed`, `TripCancelled`, and `TripCompleted` entries for Trip Intents that are active when the event is saved. A `TripNotification` belongs to one `TripIntent`, and PostgreSQL enforces a unique `(TripIntentId, DeduplicationKey)` pair. Repeated identical delay messages and repeated approach checks therefore do not create duplicate inbox rows. A cancelled intent is excluded from later event queries; notifications already created for it remain as history.

After a valid Driver location update, the notification service joins active intents' selected stops against the trip's `RouteStops`. It generates `BusApproachingDropOff` only when the selected stop has coordinates and the received bus point is within 500 meters by a Haversine distance calculation. This is a simple proximity rule; it does not predict movement or check travel direction. A unique key per intent and selected stop limits that alert to one record for that stop. Location remains stored once on the trip, and the notification row stores no duplicate coordinates.

Passengers use `GET /api/notifications` to retrieve their own persisted inbox and may mark their own item read. The endpoint is Passenger-only; other roles are forbidden and an unauthenticated request is challenged. Notification eligibility is based on active Trip Intent, while REST and SignalR live-location access remains independent. The API does not yet send push notifications; only the Passenger inbox empty state was verified on Android, not delivery or read-state changes.
