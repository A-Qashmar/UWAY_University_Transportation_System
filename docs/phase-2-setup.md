# Phase 2 Setup Guide

The project Gantt schedules Phase 2 from September 28 through October 6, 2026:

| Task | Planned dates | Foundation status |
| --- | --- | --- |
| Repository and development environment setup | Sep 28–Oct 2 | Repository structure and setup docs prepared; GitHub remote still needs team account/repository |
| Backend and database setup | Sep 29–Oct 5 | API scaffold, PostgreSQL compose file, EF Core provider and connection configuration prepared |
| Initial mobile and Admin project structure | Sep 30–Oct 6 | Flutter single-app structure and React/Vite shell prepared |

## Before the team runs it

1. Install Flutter and Docker Desktop if not already installed.
2. Configure a local PostgreSQL password and replace the API development connection string, or store it with .NET user secrets.
3. Run the restore/build and client checks shown in the root README.
4. Create a GitHub repository under the team's account and add it as the Git remote when the team is ready.

No domain tables or feature workflows are created in Phase 2. Keep schema and API contracts aligned with the agreed report before feature implementation begins.
