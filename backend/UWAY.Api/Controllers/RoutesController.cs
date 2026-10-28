using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Models;
using BusRoute = UWAY.Api.Models.Route;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize(Policy = "AuthenticatedProjectUser")]
[Route("api/routes")]
public sealed class RoutesController(UwayDbContext database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<RouteResponse>>> GetAll(CancellationToken cancellationToken)
    {
        var routes = await database.Routes
            .AsNoTracking()
            .Include(route => route.RouteStops)
                .ThenInclude(routeStop => routeStop.Stop)
            .OrderBy(route => route.Code)
            .ToListAsync(cancellationToken);

        return Ok(routes.Select(ToResponse).ToList());
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<RouteResponse>> GetById(int id, CancellationToken cancellationToken)
    {
        var route = await LoadRoute(id, cancellationToken);
        return route is null ? NotFound() : Ok(ToResponse(route));
    }

    [HttpPost]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<RouteResponse>> Create(RouteRequest request, CancellationToken cancellationToken)
    {
        var stops = await LoadStops(request.StopIds, cancellationToken);
        if (stops is null)
            return InvalidStopIds();

        var route = new BusRoute
        {
            Code = request.Code.Trim().ToUpperInvariant(),
            Name = request.Name.Trim(),
            IsActive = request.IsActive
        };
        SetStops(route, stops);
        database.Routes.Add(route);

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        return CreatedAtAction(nameof(GetById), new { id = route.Id }, ToResponse(route));
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<ActionResult<RouteResponse>> Update(int id, RouteRequest request, CancellationToken cancellationToken)
    {
        var route = await LoadRoute(id, cancellationToken);
        if (route is null)
            return NotFound();

        var stops = await LoadStops(request.StopIds, cancellationToken);
        if (stops is null)
            return InvalidStopIds();

        await using var transaction = await database.Database.BeginTransactionAsync(cancellationToken);
        route.Code = request.Code.Trim().ToUpperInvariant();
        route.Name = request.Name.Trim();
        route.IsActive = request.IsActive;
        database.RemoveRange(route.RouteStops);
        route.RouteStops.Clear();

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        SetStops(route, stops);

        try
        {
            await database.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        return Ok(ToResponse(route));
    }

    [HttpDelete("{id:int}")]
    [Authorize(Policy = "AdminOnly")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var route = await database.Routes.FindAsync([id], cancellationToken);
        if (route is null)
            return NotFound();

        database.Routes.Remove(route);
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

    private Task<BusRoute?> LoadRoute(int id, CancellationToken cancellationToken) => database.Routes
        .Include(route => route.RouteStops.OrderBy(routeStop => routeStop.StopOrder))
            .ThenInclude(routeStop => routeStop.Stop)
        .SingleOrDefaultAsync(route => route.Id == id, cancellationToken);

    private async Task<List<Stop>?> LoadStops(IReadOnlyCollection<int> stopIds, CancellationToken cancellationToken)
    {
        if (stopIds is null || stopIds.Count != stopIds.Distinct().Count())
            return null;

        var stops = await database.Stops
            .Where(stop => stopIds.Contains(stop.Id))
            .ToListAsync(cancellationToken);
        if (stops.Count != stopIds.Count)
            return null;

        var stopsById = stops.ToDictionary(stop => stop.Id);
        return stopIds.Select(stopId => stopsById[stopId]).ToList();
    }

    private static void SetStops(BusRoute route, IReadOnlyList<Stop> stops)
    {
        route.RouteStops.Clear();
        for (var index = 0; index < stops.Count; index++)
        {
            route.RouteStops.Add(new RouteStop
            {
                Route = route,
                Stop = stops[index],
                StopOrder = index + 1
            });
        }
    }

    private BadRequestObjectResult InvalidStopIds() => BadRequest(new ValidationProblemDetails(
        new Dictionary<string, string[]> { [nameof(RouteRequest.StopIds)] = ["Stop IDs must be unique and refer to existing stops."] }));

    private static RouteResponse ToResponse(BusRoute route) => new(
        route.Id,
        route.Code,
        route.Name,
        route.IsActive,
        route.RouteStops.OrderBy(routeStop => routeStop.StopOrder)
            .Select(routeStop => new RouteStopResponse(routeStop.StopId, routeStop.Stop.Name, routeStop.StopOrder, (double?)routeStop.Stop.Latitude, (double?)routeStop.Stop.Longitude, routeStop.Stop.Audience))
            .ToList());

    public sealed record RouteResponse(int Id, string Code, string Name, bool IsActive, IReadOnlyList<RouteStopResponse> Stops);
    public sealed record RouteStopResponse(int Id, string Name, int Order, double? Latitude, double? Longitude, string? Audience = null);
}
