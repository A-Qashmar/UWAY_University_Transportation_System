# Setup and Operations Guide

(This file keeps its original name `phase-2-setup.md` so existing links still work.)

See the [README](../README.md) for the short quick start. This guide adds detail and troubleshooting.

## 1. Prerequisites

Git, .NET 9 SDK, Node.js 20+, Flutter SDK, Android platform tools (`adb`), Docker Desktop.

## 2. Database

```powershell
cd database
copy .env.example .env     # set POSTGRES_PASSWORD
docker compose up -d --wait
```

PostgreSQL listens on `localhost:55432` (database `uway`, user `uway_app`, container `uway-postgres`).

## 3. API environment

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:ConnectionStrings__UwayDatabase = "Host=localhost;Port=55432;Database=uway;Username=uway_app;Password=<your password>"
```

Outside Development also set `Uway__TokenKey` to a random string of at least 32 characters.

## 4. First-time data

With the API stopped, run in order:

```powershell
dotnet run --project backend/UWAY.Api -- --migrate
dotnet run --project backend/UWAY.Api -- --import-source-stops
dotnet run --project backend/UWAY.Api -- --seed-source-routes
dotnet run --project backend/UWAY.Api -- --seed-test-users
```

Check the schema at any time with `--migration-status`. Re-run `--seed-test-users` after adding drivers.

## 5. Run

| Part | Command | Address |
| --- | --- | --- |
| API | `dotnet run --project backend/UWAY.Api --urls http://0.0.0.0:5251` | `http://localhost:5251`, `/health` |
| Admin | `cd admin; npm install; npm run dev` | `http://localhost:5173` |
| Mobile | `cd mobile; adb reverse tcp:5251 tcp:5251; flutter run` | phone |

## 6. Troubleshooting

| Symptom | What to check |
| --- | --- |
| `/health` reports the database as unreachable | Docker container running? Password in the connection string matches `database\.env`? |
| Phone cannot reach the API | `adb devices` lists the phone; run `adb reverse tcp:5251 tcp:5251` again after reconnecting USB; API started with `--urls http://0.0.0.0:5251` |
| Login says invalid credentials | Run `--seed-test-users`; password is `Uway@2026` |
| A driver has no account | Run `--seed-test-users` again |
| Map is slow on the phone | Use `flutter run --profile` instead of debug |
| Admin cannot sign in or load data | API running? `VITE_UWAY_API_URL` correct? |

## 7. Removing demonstration data

`dotnet run --project backend/UWAY.Api -- --remove-demo-routes` previews what would be deleted; add `--confirm` to delete. The four main routes, buses, drivers, stops and accounts are never touched. Development only.

## 8. Git hygiene

Do not commit `.env` files, database dumps (`*.sql`), `_backup_*` folders, Word lock files (`~$*.docx`), or build output.
