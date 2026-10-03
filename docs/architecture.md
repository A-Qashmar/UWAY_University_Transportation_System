# UWAY Architecture and Phase 2 Decisions

## System shape

The solution has three clients/components: one Flutter mobile application with Passenger and Driver areas, a React and JavaScript Admin web client, and an ASP.NET Core Web API backed by PostgreSQL. Clients communicate with the API over HTTP. The API provides role policies for Passenger, Driver, and Admin access as a starting point for later identity work.

## Decisions for the setup phase

| Area | Setup choice | Phase 2 boundary |
| --- | --- | --- |
| Mobile | Flutter/Dart, one app for Passenger and Driver | App shell only; no role workflows |
| Admin | React + JavaScript with Vite | Starter shell only |
| Backend | ASP.NET Core 9 Web API | Health endpoint and role policy names |
| Database | PostgreSQL with EF Core/Npgsql | Connection and context; domain schema deferred |
| Authentication | Authorization policies for Passenger, Driver, Admin | No identity provider, login, or tokens yet |
| Realtime, push, maps | Future integration points | SignalR, FCM, Google Maps/Mapbox remain out of setup |

## Scope source

Progress Report #1 sets the Senior Project direction: passenger trip information and trip intent, live tracking after trip start, drop-off selection, notifications, Driver operations and communication, and Admin management. It explicitly removes reservation and QR boarding from the Senior Project. The Gantt Phase 2 tasks are repository/development environment, backend/database, and initial mobile/Admin structure. Feature implementation remains in later phases.
