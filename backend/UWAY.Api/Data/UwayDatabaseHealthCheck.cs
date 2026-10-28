using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace UWAY.Api.Data;

public sealed class UwayDatabaseHealthCheck(UwayDbContext database) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var canConnect = await database.Database.CanConnectAsync(cancellationToken);

        return canConnect
            ? HealthCheckResult.Healthy("The UWAY database is reachable.")
            : HealthCheckResult.Unhealthy("The UWAY database is not reachable.");
    }
}
