# PostgreSQL local development

The Compose file runs PostgreSQL 17 on `127.0.0.1:55432` (container port `5432`), stores data in the `uway-postgres-data` volume, and waits for PostgreSQL's readiness check before reporting the container healthy.

From the project root, copy `database/.env.example` to `database/.env` and set a local password. Start the database from the `database` folder:

```powershell
docker compose up -d --wait
```

Set the API connection string in the same PowerShell session, using the password from `database/.env`:

```powershell
$env:ConnectionStrings__UwayDatabase = "Host=localhost;Port=55432;Database=uway;Username=uway_app;Password=<your-local-password>"
```

Apply the checked-in EF Core migrations, then run the API:

```powershell
dotnet run --project backend/UWAY.Api -- --migrate
dotnet run --project backend/UWAY.Api
```

The migration command exits after applying pending migrations. Normal API startup does not change the schema. The `/health` endpoint reports unhealthy when PostgreSQL cannot be reached.

For non-local environments, provide the connection string through a secret store or the `ConnectionStrings__UwayDatabase` environment variable. Do not commit `database/.env` or real credentials.
