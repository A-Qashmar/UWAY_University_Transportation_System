# UWAY Architecture

Last updated: 30 October 2026 (Progress Report #2).

## Overview

```text
Flutter app (Passenger + Driver)  ──HTTPS/JSON──►  ASP.NET Core 9 API  ──EF Core──►  PostgreSQL
React admin dashboard             ──HTTPS/JSON──►        │
        ▲                                                 └── SignalR hub /hubs/trip-locations
        └──────────── LocationUpdated (live bus position) ◄───────────────────────────┘
```

- **One API, three clients' worth of roles.** The Flutter app serves Passengers and Drivers; the React dashboard serves Admins. The role comes from the signed-in account.
- **PostgreSQL is the single source of truth.** The API changes the schema only through explicit migrations (`--migrate`); normal startup never alters the database.
- **Live location uses SignalR plus REST.** The Driver app posts GPS points to `POST /api/trips/{id}/location`. The API validates the sender, stores the latest point on the trip row, and broadcasts `LocationUpdated` to clients that joined the trip group. Clients can reload the latest point with `GET` after a reconnect.

## Backend (`backend/UWAY.Api`)

| Part | Notes |
| --- | --- |
| Controllers (12) | Auth, Trips, TripIntents, TripCapacity, TripLocations, Routes, Stops, Buses, Drivers, Notifications, Reports, Health |
| Data | EF Core with Npgsql; 13 entity sets; 15 migrations |
| Authentication | `POST /api/auth/login` verifies a PBKDF2 hash (SHA-256, 210,000 iterations) and returns an HMAC-SHA256 bearer token valid for 12 hours |
| Authorization | Policies: AdminOnly, DriverOnly, PassengerOnly, DriverOrAdmin, PassengerOrDriver, PassengerOrAdmin, PassengerDriverOrAdmin, AuthenticatedProjectUser |
| Real time | `TripLocationHub` (`JoinTrip`, `LeaveTrip`, `LocationUpdated`) |
| Services | Trip lifecycle, capacity, notifications (trip and user), reports and attachments, test-user seeding, source-stop import, source-route seeding |

### Domain rules

- **Trip status** is `Scheduled → Started → Finished`. Delay and cancellation are alerts (`delayMinutes`, `cancelledAtUtc` and a reason), not statuses. An Admin can restore a cancelled trip. Invalid transitions return 409; edits use a concurrency version.
- **Start / end:** the assigned Driver or any Admin. **GPS update and Bus Nearly Full:** the assigned Driver only.
- **Audience:** every trip is `Men` or `Women`. Passengers only see and join trips of their own audience, and stops reserved for one audience (UOS – M3 / UOS – W3) are not allowed on trips of the other.
- **Trip Intent** stores one drop-off stop per passenger per trip. The API checks route membership and audience. Direction-specific choices (campus stops for inbound trips, route stops for outbound trips) are inferred from stop names in the mobile app; the API does not validate direction.
- **Capacity:** Expected Riders = active intents. Against the assigned bus capacity: under 80% `Normal`, from 80% `NearlyFull`, equal `Full`, above `OverCapacity`.
- **Notifications:** stored per recipient with a unique key to prevent duplicates. Trip notifications go to passengers with an active intent (including *bus approaching your drop-off*, 500 m Haversine). User notifications cover all roles (report received/updated, trip assigned/changed, Bus Nearly Full, and trip events). Delivery is in-app (polling); no push service.
- **Reports:** categories LostItem, TripProblem, DriverOrBus, Other; statuses Open, InReview, Resolved; up to five attachments (image ≤ 10 MB, video ≤ 30 MB) stored in PostgreSQL.

### Stops and routes

University City stops (86 collected points) are imported with `--import-source-stops` using a stable SHA-256 key. `--seed-source-routes` builds the four main routes (`KF-IN`, `KF-OUT`, `HRH-IN`, `HRH-OUT`) following the collected `source_order`. Stop order and the “official” status of these routes await confirmation from the University City; maps draw straight lines between stops.

## Admin dashboard (`admin`)

React with Vite and Leaflet. Signs in with an Admin account (token kept for the browser session). Sections: Live Operations (active trips on a map, Expected Riders, capacity, Call Driver), Trips, Routes, Stops, Fleet (buses and drivers), Reports, Source map, and a notification bell. The API address defaults to `http://localhost:5251` and can be changed with `VITE_UWAY_API_URL`.

## Mobile app (`mobile`)

Flutter with `flutter_map` (OpenStreetMap), `geolocator` and `signalr_core`. After sign-in the account decides whether the Passenger or the Driver interface opens. The session is held in memory only. Debug builds also offer a *Developer mode (sample data)* entry that uses `DemoUwayDataSource` and needs no API.

## Security notes

- Tokens are signed; outside Development `Uway:TokenKey` (≥ 32 characters) is required.
- Test accounts and their shared password exist only for local development (`--seed-test-users` is Development-only).
- Development header authentication is optional, loopback-only, and off by default; the apps do not use it.
- Attachments are readable only by their owner and Admins.

## Not implemented

Registration and password reset, university single sign-on, push notifications, emergency alerts, Driver–Admin chat, trip history, real road geometry for routes, Arabic/RTL, and backend automated tests.
