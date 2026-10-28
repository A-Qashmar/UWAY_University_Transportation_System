using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize(Policy = "AdminOnly")]
[Route("api/buses")]
public sealed class BusesController(UwayDbContext database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<BusResponse>>> GetAll(CancellationToken cancellationToken)
    {
        var buses = await database.Buses.AsNoTracking()
            .OrderBy(bus => bus.FleetNumber)
            .ToListAsync(cancellationToken);
        var drivers = await database.Drivers.AsNoTracking()
            .Where(driver => driver.AssignedBusId != null)
            .ToListAsync(cancellationToken);
        return Ok(buses.Select(bus => ToResponse(bus, drivers.FirstOrDefault(driver => driver.AssignedBusId == bus.Id))).ToList());
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<BusResponse>> GetById(int id, CancellationToken cancellationToken)
    {
        var bus = await database.Buses.AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (bus is null)
            return NotFound();
        var driver = await database.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(item => item.AssignedBusId == id, cancellationToken);
        return Ok(ToResponse(bus, driver));
    }

    [HttpPost]
    public async Task<ActionResult<BusResponse>> Create(BusRequest request, CancellationToken cancellationToken)
    {
        var bus = new Bus
        {
            FleetNumber = request.FleetNumber.Trim().ToUpperInvariant(),
            Capacity = request.Capacity,
            IsActive = request.IsActive
        };
        database.Buses.Add(bus);

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        var linked = await LinkDriver(bus.Id, request.AssignedDriverId, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = bus.Id }, ToResponse(bus, linked));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<BusResponse>> Update(int id, BusRequest request, CancellationToken cancellationToken)
    {
        var bus = await database.Buses.FindAsync([id], cancellationToken);
        if (bus is null)
            return NotFound();

        bus.FleetNumber = request.FleetNumber.Trim().ToUpperInvariant();
        bus.Capacity = request.Capacity;
        bus.IsActive = request.IsActive;

        try
        {
            await database.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (DatabaseErrorResponses.IsConstraintViolation(exception))
        {
            return DatabaseErrorResponses.ConstraintConflict(this, exception);
        }

        var linked = await LinkDriver(bus.Id, request.AssignedDriverId, cancellationToken);
        return Ok(ToResponse(bus, linked));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var bus = await database.Buses.FindAsync([id], cancellationToken);
        if (bus is null)
            return NotFound();

        database.Buses.Remove(bus);
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

    /// <summary>Makes <paramref name="driverId"/> the bus's driver (or clears it when null).</summary>
    private async Task<Driver?> LinkDriver(int busId, int? driverId, CancellationToken cancellationToken)
    {
        var current = await database.Drivers.Where(driver => driver.AssignedBusId == busId).ToListAsync(cancellationToken);
        var previous = current.Where(driver => driver.Id != driverId).ToList();
        if (previous.Count > 0)
        {
            // Clear first so the unique index never sees two drivers on one bus.
            foreach (var driver in previous)
                driver.AssignedBusId = null;
            await database.SaveChangesAsync(cancellationToken);
        }

        var linked = current.FirstOrDefault(driver => driver.Id == driverId);
        if (driverId is int id && linked is null)
        {
            linked = await database.Drivers.SingleOrDefaultAsync(driver => driver.Id == id, cancellationToken);
            if (linked is not null)
            {
                linked.AssignedBusId = busId;
                await database.SaveChangesAsync(cancellationToken);
            }
        }
        return linked;
    }

    private static BusResponse ToResponse(Bus bus, Driver? driver) =>
        new(bus.Id, bus.FleetNumber, bus.Capacity, bus.IsActive, driver?.Id, driver?.FullName);

    public sealed record BusResponse(int Id, string FleetNumber, int Capacity, bool IsActive, int? AssignedDriverId, string? AssignedDriverName);
}
