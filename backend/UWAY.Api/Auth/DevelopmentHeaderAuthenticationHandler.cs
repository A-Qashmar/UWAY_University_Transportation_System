using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace UWAY.Api.Auth;

public sealed class DevelopmentHeaderAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Uway.DevelopmentHeader";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (Context.Connection.RemoteIpAddress is not { } remoteAddress || !IPAddress.IsLoopback(remoteAddress))
            return Task.FromResult(AuthenticateResult.NoResult());

        var role = Request.Headers["X-Uway-Dev-Role"].ToString();
        if (role is not ("Admin" or "Driver" or "Passenger"))
            return Task.FromResult(AuthenticateResult.NoResult());

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, Request.Headers["X-Uway-Dev-UserId"].ToString() is { Length: > 0 } userId
                ? userId
                : "local-development-user"),
            new(ClaimTypes.Name, "Local Development User"),
            new(ClaimTypes.Role, role)
        };

        if (role == "Driver")
        {
            var driverId = Request.Headers["X-Uway-Dev-DriverId"].ToString();
            if (!int.TryParse(driverId, out var parsedId) || parsedId <= 0)
                return Task.FromResult(AuthenticateResult.NoResult());
            claims.Add(new Claim(UwayClaimTypes.DriverId, parsedId.ToString()));
        }

        var identity = new ClaimsIdentity(claims, SchemeName, ClaimTypes.Name, ClaimTypes.Role);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
