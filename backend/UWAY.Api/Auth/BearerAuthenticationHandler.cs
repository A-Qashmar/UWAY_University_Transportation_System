using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace UWAY.Api.Auth;

public sealed class BearerAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    TokenService tokens)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "Uway.Bearer";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        string? token = null;
        var header = Request.Headers.Authorization.ToString();
        if (header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            token = header["Bearer ".Length..].Trim();
        else if (Request.Path.StartsWithSegments("/hubs"))
            token = Request.Query["access_token"].ToString(); // SignalR websockets cannot send headers.

        if (string.IsNullOrEmpty(token))
            return Task.FromResult(AuthenticateResult.NoResult());

        var payload = tokens.Validate(token);
        if (payload is null)
            return Task.FromResult(AuthenticateResult.Fail("The session is invalid or has expired."));

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, payload.Sub),
            new(ClaimTypes.Name, payload.Name),
            new(ClaimTypes.Role, payload.Role)
        };
        if (payload.DriverId is int driverId)
            claims.Add(new Claim(UwayClaimTypes.DriverId, driverId.ToString()));

        var identity = new ClaimsIdentity(claims, SchemeName, ClaimTypes.Name, ClaimTypes.Role);
        return Task.FromResult(AuthenticateResult.Success(
            new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName)));
    }
}
