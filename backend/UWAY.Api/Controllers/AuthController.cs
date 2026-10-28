using System.Collections.Concurrent;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Data;

namespace UWAY.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(UwayDbContext database, TokenService tokens) : ControllerBase
{
    // Wrong passwords are limited per email and address: 5 tries, then a 5 minute wait.
    private static readonly ConcurrentDictionary<string, (int Count, DateTimeOffset Since)> Failures = new();
    private static readonly string DummyHash = UwayPasswordHasher.Hash("not-a-real-password");

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<SessionResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var key = $"{email}|{HttpContext.Connection.RemoteIpAddress}";
        if (Failures.TryGetValue(key, out var failed) &&
            failed.Count >= 5 && DateTimeOffset.UtcNow - failed.Since < TimeSpan.FromMinutes(5))
            return StatusCode(StatusCodes.Status429TooManyRequests,
                new ProblemDetails { Title = "Too many attempts", Detail = "Too many wrong passwords. Please wait a few minutes and try again." });

        var user = await database.Users.AsNoTracking()
            .SingleOrDefaultAsync(item => item.Email == email, cancellationToken);
        var passwordOk = UwayPasswordHasher.Verify(request.Password, user?.PasswordHash ?? DummyHash);
        if (user is null || !user.IsActive || !passwordOk)
        {
            Failures.AddOrUpdate(key, _ => (1, DateTimeOffset.UtcNow),
                (_, old) => DateTimeOffset.UtcNow - old.Since > TimeSpan.FromMinutes(5)
                    ? (1, DateTimeOffset.UtcNow)
                    : (old.Count + 1, old.Since));
            return Unauthorized(new ProblemDetails { Title = "Sign-in failed", Detail = "The email or password is not correct." });
        }

        Failures.TryRemove(key, out _);
        return Ok(await BuildSession(user.Id, user.Email, user.Role, user.FullName, user.DriverId, cancellationToken));
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<SessionResponse>> Me(CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id))
            return Unauthorized();
        var user = await database.Users.AsNoTracking().SingleOrDefaultAsync(item => item.Id == id && item.IsActive, cancellationToken);
        return user is null
            ? Unauthorized()
            : Ok(await BuildSession(user.Id, user.Email, user.Role, user.FullName, user.DriverId, cancellationToken));
    }

    private async Task<SessionResponse> BuildSession(Guid id, string email, string role, string fullName, int? driverId, CancellationToken cancellationToken)
    {
        string? gender = null;
        if (role == "Passenger")
        {
            var passengerId = id.ToString();
            gender = await database.Passengers.AsNoTracking()
                .Where(item => item.Id == passengerId).Select(item => item.Gender)
                .SingleOrDefaultAsync(cancellationToken);
        }
        var (token, expires) = tokens.Create(id.ToString(), role, fullName, driverId);
        return new SessionResponse(token, expires, id.ToString(), email, fullName, role, gender, driverId);
    }

    public sealed class LoginRequest
    {
        [Required, MaxLength(200)] public string Email { get; init; } = string.Empty;
        [Required, MaxLength(200)] public string Password { get; init; } = string.Empty;
    }

    public sealed record SessionResponse(
        string Token, DateTimeOffset ExpiresAtUtc, string UserId, string Email,
        string FullName, string Role, string? Gender, int? DriverId);
}
