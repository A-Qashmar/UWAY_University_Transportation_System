# Verification Status

Last updated: 30 October 2026.

This page states honestly what has and has not been verified. The earlier version (24 October) is kept in [archive/verification-status-2026-10-24.md](archive/verification-status-2026-10-24.md) for history; its failures have since been resolved.

## Tested by the team

The team has run the system end to end with the API, PostgreSQL and the admin dashboard on a PC and the mobile app on a physical Android phone, using the seeded test accounts. The features marked *Built* in [frontend-status.md](frontend-status.md) for Phase 3 and the first Phase 4 features (live location, Trip Intent, capacity, notifications) were exercised by hand this way.

## Automated checks

| Check | Command | Status |
| --- | --- | --- |
| Flutter widget and unit tests | `cd mobile; flutter test` | Tests exist in `mobile/test`; run before each release |
| .NET build | `dotnet build UWAY.sln` | Run before each release |
| Admin production build | `cd admin; npm run build` | Run before each release |
| Backend automated tests | – | None yet |

Run these commands and record the results (with screenshots) before the progress report is submitted.

## Not yet verified

- Formal test plan, test cases and results (Phase 5).
- Behavior with many simultaneous users, and GPS behavior over long trips.
- Route stop order and real road geometry (pending University City data).
- Behavior on iOS and on devices other than the team’s Android phone.
