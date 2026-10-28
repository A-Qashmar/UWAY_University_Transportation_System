using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Controllers;

/// <summary>The signed-in user's inbox: trip events (passengers) plus report and operations messages.</summary>
[ApiController]
[Authorize(Policy = "AuthenticatedProjectUser")]
[Route("api/notifications")]
public sealed class NotificationsController(UwayDbContext database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TripNotificationResponse>>> GetMine(
        [FromQuery] int take = 50,
        CancellationToken cancellationToken = default)
    {
        if (take is < 1 or > 100)
            return BadRequest(new ProblemDetails
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "The notification page size is invalid.",
                Detail = "Choose a value from 1 to 100."
            });

        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(userId))
            return Forbid();

        var messages = await database.UserNotifications.AsNoTracking()
            .Where(item => item.UserId == userId)
            .OrderByDescending(item => item.CreatedAtUtc)
            .Take(take)
            .Select(item => new TripNotificationResponse(
                item.Id, item.TripId, item.Type, item.Title, item.Message, item.CreatedAtUtc, item.ReadAtUtc))
            .ToListAsync(cancellationToken);

        if (User.IsInRole("Passenger"))
        {
            var tripEvents = await database.TripNotifications.AsNoTracking()
                .Where(item => item.TripIntent.PassengerId == userId)
                .OrderByDescending(item => item.CreatedAtUtc)
                .Take(take)
                .Select(item => new TripNotificationResponse(
                    item.Id, item.TripIntent.TripId, item.Type.ToString(), item.Title, item.Message,
                    item.CreatedAtUtc, item.ReadAtUtc))
                .ToListAsync(cancellationToken);
            messages.AddRange(tripEvents);
        }

        return Ok(messages.OrderByDescending(item => item.CreatedAtUtc).Take(take).ToList());
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<UnreadCountResponse>> UnreadCount(CancellationToken cancellationToken)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(userId))
            return Forbid();

        var count = await database.UserNotifications.CountAsync(
            item => item.UserId == userId && item.ReadAtUtc == null, cancellationToken);
        if (User.IsInRole("Passenger"))
            count += await database.TripNotifications.CountAsync(
                item => item.TripIntent.PassengerId == userId && item.ReadAtUtc == null, cancellationToken);
        return Ok(new UnreadCountResponse(count));
    }

    [HttpPut("{notificationId:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid notificationId, CancellationToken cancellationToken)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(userId))
            return Forbid();

        var message = await database.UserNotifications
            .SingleOrDefaultAsync(item => item.Id == notificationId && item.UserId == userId, cancellationToken);
        if (message is not null)
        {
            message.ReadAtUtc ??= DateTimeOffset.UtcNow;
            await database.SaveChangesAsync(cancellationToken);
            return NoContent();
        }

        var notification = await database.TripNotifications
            .Include(item => item.TripIntent)
            .SingleOrDefaultAsync(item => item.Id == notificationId &&
                item.TripIntent.PassengerId == userId, cancellationToken);
        if (notification is null)
            return NotFound();

        notification.ReadAtUtc ??= DateTimeOffset.UtcNow;
        await database.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(userId))
            return Forbid();

        var now = DateTimeOffset.UtcNow;
        foreach (var item in await database.UserNotifications
                     .Where(item => item.UserId == userId && item.ReadAtUtc == null).ToListAsync(cancellationToken))
            item.ReadAtUtc = now;
        if (User.IsInRole("Passenger"))
            foreach (var item in await database.TripNotifications
                         .Where(item => item.TripIntent.PassengerId == userId && item.ReadAtUtc == null).ToListAsync(cancellationToken))
                item.ReadAtUtc = now;
        await database.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    public sealed record UnreadCountResponse(int Count);

    public sealed record TripNotificationResponse(
        Guid Id,
        Guid? TripId,
        string Type,
        string Title,
        string Message,
        DateTimeOffset CreatedAtUtc,
        DateTimeOffset? ReadAtUtc);
}
