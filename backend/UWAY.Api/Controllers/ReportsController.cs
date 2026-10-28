using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Data;
using UWAY.Api.Models;
using UWAY.Api.Services;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/reports")]
public sealed class ReportsController(UwayDbContext database, PassengerAccess passengerAccess, UserNotificationService inbox) : ControllerBase
{
    [HttpPost]
    [Authorize(Policy = "PassengerOrDriver")]
    public async Task<ActionResult<ReportResponse>> Create(CreateReportRequest request, CancellationToken cancellationToken)
    {
        var passengerId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(passengerId) || passengerId.Length > 120)
            return Forbid();

        var description = request.Description?.Trim() ?? string.Empty;
        if (description.Length < 5)
            return Invalid(nameof(request.Description), "Please describe the report in at least a few words.");
        if (!ReportCategories.All.Contains(request.Category))
            return Invalid(nameof(request.Category), "Choose a report type from the list.");

        if (request.TripId is Guid tripId)
        {
            var trip = await database.Trips.AsNoTracking()
                .SingleOrDefaultAsync(item => item.Id == tripId, cancellationToken);
            bool allowed;
            if (User.IsInRole("Driver"))
                allowed = trip is not null && int.TryParse(User.FindFirst(UwayClaimTypes.DriverId)?.Value, out var driverId) && trip.DriverId == driverId;
            else
            {
                var gender = await passengerAccess.GetGenderAsync(User, cancellationToken);
                allowed = trip is not null && gender is not null && trip.Audience == gender;
            }
            if (!allowed)
                return Invalid(nameof(request.TripId), "That trip could not be found.");
        }

        var now = DateTimeOffset.UtcNow;
        var report = new Report
        {
            Id = Guid.NewGuid(),
            PassengerId = passengerId,
            Category = request.Category,
            TripId = request.TripId,
            Description = description,
            Status = ReportStatuses.Open,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
        database.Reports.Add(report);
        var sender = Guid.TryParse(passengerId, out var senderGuid)
            ? await database.Users.AsNoTracking().SingleOrDefaultAsync(user => user.Id == senderGuid, cancellationToken)
            : null;
        await inbox.NotifyAdminsAsync(UserNotificationTypes.ReportReceived, "New report received",
            $"{sender?.FullName ?? "A user"} ({(User.IsInRole("Driver") ? "driver" : "passenger")}): {Label(request.Category)}. {Short(description)}",
            $"report-received:{report.Id}", report.TripId, cancellationToken);
        await database.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetMine), await ToResponse(report, cancellationToken));
    }

    [HttpGet("mine")]
    [Authorize(Policy = "PassengerOrDriver")]
    public async Task<ActionResult<IReadOnlyList<ReportResponse>>> GetMine(CancellationToken cancellationToken)
    {
        var passengerId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrWhiteSpace(passengerId))
            return Forbid();

        var reports = await database.Reports.AsNoTracking()
            .Include(report => report.Trip).ThenInclude(trip => trip!.Route)
            .Where(report => report.PassengerId == passengerId)
            .OrderByDescending(report => report.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        return Ok(await WithAttachments(reports.Select(report => Map(report, null)).ToList(), cancellationToken));
    }

    [HttpGet]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<IReadOnlyList<ReportResponse>>> GetAll(CancellationToken cancellationToken)
    {
        var reports = await database.Reports.AsNoTracking()
            .Include(report => report.Trip).ThenInclude(trip => trip!.Route)
            .OrderByDescending(report => report.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        var ids = reports.Select(report => report.PassengerId).Distinct().ToList();
        var profiles = await SenderProfiles(ids, cancellationToken);
        return Ok(await WithAttachments(reports.Select(report =>
        {
            profiles.TryGetValue(report.PassengerId, out var profile);
            return Map(report, profile);
        }).ToList(), cancellationToken));
    }

    [HttpPut("{id:guid}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<ReportResponse>> Update(Guid id, UpdateReportRequest request, CancellationToken cancellationToken)
    {
        if (!ReportStatuses.All.Contains(request.Status))
            return Invalid(nameof(request.Status), "Choose Open, InReview or Resolved.");

        var report = await database.Reports
            .Include(item => item.Trip).ThenInclude(trip => trip!.Route)
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (report is null)
            return NotFound();

        report.Status = request.Status;
        report.AdminResponse = string.IsNullOrWhiteSpace(request.AdminResponse) ? null : request.AdminResponse.Trim();
        report.UpdatedAtUtc = DateTimeOffset.UtcNow;
        var statusText = report.Status switch { ReportStatuses.InReview => "is being reviewed", ReportStatuses.Resolved => "was resolved", _ => "was reopened" };
        await inbox.NotifyUserAsync(report.PassengerId, UserNotificationTypes.ReportUpdated, "Your report was updated",
            $"Your report ({Label(report.Category)}) {statusText}." + (report.AdminResponse is null ? "" : $" Reply: {Short(report.AdminResponse)}"),
            $"report-updated:{report.Id}:{report.UpdatedAtUtc.UtcTicks}", report.TripId, cancellationToken);
        await database.SaveChangesAsync(cancellationToken);
        var profiles = await SenderProfiles([report.PassengerId], cancellationToken);
        profiles.TryGetValue(report.PassengerId, out var profile);
        return Ok((await WithAttachments([Map(report, profile)], cancellationToken))[0]);
    }

    private const int MaxAttachments = 5;
    private const long MaxImageBytes = 10 * 1024 * 1024;
    private const long MaxVideoBytes = 30 * 1024 * 1024;

    /// <summary>Adds one photo or video to a report the caller owns.</summary>
    [HttpPost("{id:guid}/attachments")]
    [Authorize(Policy = "PassengerOrDriver")]
    [RequestSizeLimit(40 * 1024 * 1024)]
    public async Task<ActionResult<AttachmentInfo>> AddAttachment(Guid id, IFormFile file, CancellationToken cancellationToken)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var report = await database.Reports.AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id && item.PassengerId == userId, cancellationToken);
        if (report is null)
            return NotFound();
        if (file is null || file.Length == 0)
            return Invalid("file", "Choose a photo or video.");

        var type = (file.ContentType ?? string.Empty).ToLowerInvariant();
        var isImage = type.StartsWith("image/");
        var isVideo = type.StartsWith("video/");
        if (!isImage && !isVideo)
            return Invalid("file", "Only photos and videos can be attached.");
        if (file.Length > (isImage ? MaxImageBytes : MaxVideoBytes))
            return Invalid("file", isImage ? "A photo can be at most 10 MB." : "A video can be at most 30 MB.");
        if (await database.ReportAttachments.CountAsync(item => item.ReportId == id, cancellationToken) >= MaxAttachments)
            return Invalid("file", $"At most {MaxAttachments} files per report.");

        await using var buffer = new MemoryStream();
        await file.CopyToAsync(buffer, cancellationToken);
        var name = Path.GetFileName(file.FileName ?? "file");
        var attachment = new ReportAttachment
        {
            Id = Guid.NewGuid(),
            ReportId = id,
            FileName = name.Length > 200 ? name[^200..] : name,
            ContentType = type.Length > 100 ? type[..100] : type,
            SizeBytes = file.Length,
            Data = buffer.ToArray(),
            CreatedAtUtc = DateTimeOffset.UtcNow
        };
        database.ReportAttachments.Add(attachment);
        await database.SaveChangesAsync(cancellationToken);
        return Ok(new AttachmentInfo(attachment.Id, attachment.FileName, attachment.ContentType, attachment.SizeBytes));
    }

    /// <summary>Downloads an attachment: the admin, or the user who sent the report.</summary>
    [HttpGet("attachments/{attachmentId:guid}")]
    public async Task<IActionResult> GetAttachment(Guid attachmentId, CancellationToken cancellationToken)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var item = await database.ReportAttachments.AsNoTracking()
            .Include(attachment => attachment.Report)
            .SingleOrDefaultAsync(attachment => attachment.Id == attachmentId, cancellationToken);
        if (item is null || (!User.IsInRole("Admin") && item.Report.PassengerId != userId))
            return NotFound();
        return File(item.Data, item.ContentType, item.FileName, enableRangeProcessing: true);
    }

    private async Task<List<ReportResponse>> WithAttachments(List<ReportResponse> reports, CancellationToken cancellationToken)
    {
        var ids = reports.Select(report => report.Id).ToList();
        var files = await database.ReportAttachments.AsNoTracking()
            .Where(item => ids.Contains(item.ReportId))
            .OrderBy(item => item.CreatedAtUtc)
            .Select(item => new { item.ReportId, Info = new AttachmentInfo(item.Id, item.FileName, item.ContentType, item.SizeBytes) })
            .ToListAsync(cancellationToken);
        var byReport = files.GroupBy(item => item.ReportId).ToDictionary(group => group.Key, group => (IReadOnlyList<AttachmentInfo>)group.Select(item => item.Info).ToList());
        return reports.Select(report => report with { Attachments = byReport.GetValueOrDefault(report.Id) ?? [] }).ToList();
    }

    private async Task<ReportResponse> ToResponse(Report report, CancellationToken cancellationToken)
    {
        if (report.TripId is Guid tripId)
            report.Trip = await database.Trips.AsNoTracking().Include(trip => trip.Route)
                .SingleOrDefaultAsync(trip => trip.Id == tripId, cancellationToken);
        return Map(report, null);
    }

    private async Task<Dictionary<string, Sender>> SenderProfiles(List<string> ids, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, Sender>();
        foreach (var passenger in await database.Passengers.AsNoTracking().Where(item => ids.Contains(item.Id)).ToListAsync(cancellationToken))
            result[passenger.Id] = new Sender(passenger.FullName, passenger.Email, "Passenger");
        foreach (var user in await database.Users.AsNoTracking().ToListAsync(cancellationToken))
            if (ids.Contains(user.Id.ToString()))
                result[user.Id.ToString()] = new Sender(user.FullName, user.Email, user.Role);
        return result;
    }

    private static string Label(string category) => category switch
    {
        "LostItem" => "lost item",
        "TripProblem" => "trip problem",
        "DriverOrBus" => "driver or bus",
        _ => "other"
    };

    private static string Short(string text) => text.Length <= 160 ? text : text[..160] + "…";

    private sealed record Sender(string Name, string Email, string Role);

    private static ReportResponse Map(Report report, Sender? profile) => new(
        report.Id,
        report.Category,
        report.Description,
        report.Status,
        report.AdminResponse,
        report.TripId,
        report.Trip?.Route.Name,
        report.Trip?.DepartureAtUtc,
        profile?.Name,
        profile?.Email,
        report.CreatedAtUtc,
        report.UpdatedAtUtc,
        profile?.Role);

    private BadRequestObjectResult Invalid(string field, string message) =>
        BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]> { [field] = [message] }));

    public sealed class CreateReportRequest
    {
        [Required]
        public string Category { get; init; } = string.Empty;
        public Guid? TripId { get; init; }
        [MaxLength(1000)]
        public string? Description { get; init; }
    }

    public sealed class UpdateReportRequest
    {
        [Required]
        public string Status { get; init; } = string.Empty;
        [MaxLength(1000)]
        public string? AdminResponse { get; init; }
    }

    public sealed record ReportResponse(
        Guid Id,
        string Category,
        string Description,
        string Status,
        string? AdminResponse,
        Guid? TripId,
        string? TripRouteName,
        DateTimeOffset? TripDepartureAtUtc,
        string? PassengerName,
        string? PassengerEmail,
        DateTimeOffset CreatedAtUtc,
        DateTimeOffset UpdatedAtUtc,
        string? SenderRole,
        IReadOnlyList<AttachmentInfo>? Attachments = null);

    public sealed record AttachmentInfo(Guid Id, string FileName, string ContentType, long SizeBytes);
}
