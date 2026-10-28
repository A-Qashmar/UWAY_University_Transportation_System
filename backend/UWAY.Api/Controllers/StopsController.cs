using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize(Policy = "AuthenticatedProjectUser")]
[Route("api/stops")]
public sealed class StopsController(UwayDbContext database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<StopResponse>>> GetAll(CancellationToken cancellationToken)
    {
        var stops = await database.Stops.AsNoTracking().OrderBy(stop => stop.Name).ToListAsync(cancellationToken);
        return Ok(stops.Select(ToResponse).ToList());
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<StopResponse>> GetById(int id, CancellationToken cancellationToken)
    {
        var stop = await database.Stops.AsNoTracking().SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        return stop is null ? NotFound() : Ok(ToResponse(stop));
    }

    [HttpPost]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<StopResponse>> Create(StopRequest request, CancellationToken cancellationToken)
    {
        if (!CoordinatesArePaired(request))
            return InvalidCoordinates();

        var stop = new Stop
        {
            Name = request.Name.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            IsActive = request.IsActive,
            Audience = string.IsNullOrWhiteSpace(request.Audience) ? null : request.Audience
        };
        database.Stops.Add(stop);
        await database.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = stop.Id }, ToResponse(stop));
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<StopResponse>> Update(int id, StopRequest request, CancellationToken cancellationToken)
    {
        if (!CoordinatesArePaired(request))
            return InvalidCoordinates();

        var stop = await database.Stops.FindAsync([id], cancellationToken);
        if (stop is null)
            return NotFound();

        stop.Name = request.Name.Trim();
        stop.Latitude = request.Latitude;
        stop.Longitude = request.Longitude;
        stop.IsActive = request.IsActive;
        stop.Audience = string.IsNullOrWhiteSpace(request.Audience) ? null : request.Audience;
        await database.SaveChangesAsync(cancellationToken);
        return Ok(ToResponse(stop));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var stop = await database.Stops.FindAsync([id], cancellationToken);
        if (stop is null)
            return NotFound();

        database.Stops.Remove(stop);
        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        return NoContent();
    }

    private static bool CoordinatesArePaired(StopRequest request) =>
        request.Latitude.HasValue == request.Longitude.HasValue;

    private BadRequestObjectResult InvalidCoordinates() => BadRequest(new ValidationProblemDetails(
        new Dictionary<string, string[]> { [nameof(StopRequest.Latitude)] = ["Provide both coordinates or leave both empty."] }));

    private static StopResponse ToResponse(Stop stop) => new(
        stop.Id, stop.Name, stop.Latitude, stop.Longitude, stop.IsActive, stop.SourceGroup, stop.Audience);

    public sealed record StopResponse(
        int Id, string Name, decimal? Latitude, decimal? Longitude, bool IsActive, string? SourceGroup, string? Audience = null);
}
