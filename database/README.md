# PostgreSQL

Local PostgreSQL is defined in `docker-compose.yml`. Copy `.env.example` to `.env` and set a local password before starting the service. The API connection string is configured in `backend/UWAY.Api/appsettings.json`; use environment variables or user secrets for credentials outside local development.

No UWAY domain tables are created in Phase 2. Schema design belongs with the core feature work.
