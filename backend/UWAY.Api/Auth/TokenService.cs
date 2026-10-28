using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace UWAY.Api.Auth;

public sealed record TokenPayload(string Sub, string Role, string Name, int? DriverId, long Exp);

/// <summary>Creates and validates signed (HMAC-SHA256) session tokens.</summary>
public sealed class TokenService
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromHours(12);
    private readonly byte[] _key;

    public TokenService(IConfiguration configuration, IHostEnvironment environment)
    {
        var key = configuration["Uway:TokenKey"];
        if (string.IsNullOrWhiteSpace(key) || key.Length < 32)
        {
            if (!environment.IsDevelopment())
                throw new InvalidOperationException("Set Uway:TokenKey to a random secret of at least 32 characters.");
            key = "uway-development-only-token-key-change-me-0123456789";
        }
        _key = Encoding.UTF8.GetBytes(key);
    }

    public (string Token, DateTimeOffset ExpiresAtUtc) Create(string sub, string role, string name, int? driverId)
    {
        var expires = DateTimeOffset.UtcNow.Add(Lifetime);
        var payload = JsonSerializer.SerializeToUtf8Bytes(new TokenPayload(sub, role, name, driverId, expires.ToUnixTimeSeconds()));
        var body = Base64Url(payload);
        return ($"{body}.{Base64Url(Sign(body))}", expires);
    }

    public TokenPayload? Validate(string token)
    {
        var parts = token.Split('.');
        if (parts.Length != 2) return null;
        try
        {
            if (!CryptographicOperations.FixedTimeEquals(Sign(parts[0]), FromBase64Url(parts[1])))
                return null;
            var payload = JsonSerializer.Deserialize<TokenPayload>(FromBase64Url(parts[0]));
            return payload is null || payload.Exp < DateTimeOffset.UtcNow.ToUnixTimeSeconds() ? null : payload;
        }
        catch (Exception ex) when (ex is FormatException or JsonException)
        {
            return null;
        }
    }

    private byte[] Sign(string body) => HMACSHA256.HashData(_key, Encoding.ASCII.GetBytes(body));

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static byte[] FromBase64Url(string value)
    {
        var s = value.Replace('-', '+').Replace('_', '/');
        return Convert.FromBase64String(s.PadRight(s.Length + (4 - s.Length % 4) % 4, '='));
    }
}
