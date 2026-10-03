# UWAY — Smart University Transportation System

"UWAY - Smart University Transportation System - Senior Project UoS"

UWAY is the University of Sharjah Senior Project advanced prototype. It provides passenger transportation information and supports driver and administrator operations. The Senior Project explicitly excludes reservations and QR-based boarding.

## Phase 2 foundation

This repository contains the shared project structure and starter applications. The Passenger and Driver experiences live in one Flutter app. The Admin dashboard uses React and JavaScript. The API uses ASP.NET Core 9 and Entity Framework Core with PostgreSQL. Detailed feature workflows begin in Phase 3.

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

From `database/`, copy `.env.example` to `.env` and set a local password, then run `docker compose up -d`. The API connection string is in `backend/UWAY.Api/appsettings.json`. Replace its development placeholder or use .NET user secrets; never commit real credentials.

## Run the API

```powershell
dotnet restore UWAY.sln
dotnet run --project backend/UWAY.Api
```

The API health endpoint is `/health`. Role authorization policies are ready for `Passenger`, `Driver`, and `Admin`; an identity provider and login flow are intentionally deferred.

## Run the Admin shell

```powershell
cd admin
npm install
npm run dev
```

## Run the mobile app

```powershell
cd mobile
flutter pub get
flutter run
```

## Scope boundary

Phase 2 establishes the repository and development environment, backend/database connection, and initial mobile/Admin structure. It does not implement trips, routes, stops, trip intent, GPS tracking, notifications, reports, messaging, or operational workflows. SignalR, FCM, and a map provider remain future integrations. See [the architecture note](docs/architecture.md) and [Phase 2 setup guide](docs/phase-2-setup.md).
