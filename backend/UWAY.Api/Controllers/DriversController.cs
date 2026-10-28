using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Contracts;
using UWAY.Api.Data;
using UWAY.Api.Models;

namespace UWAY.Api.Controllers;

[ApiController]
[Authorize(Policy = "AdminOnly")]
[Route("api/drivers")]
public sealed class DriversController(UwayDbContext database) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<DriverResponse>>> GetAll(CancellationToken cancellationToken)
    {
        var drivers = await database.Drivers.AsNoTracking()
            .OrderBy(driver => driver.FullName)
            .ToListAsync(cancellationToken);
        return Ok(drivers.Select(ToResponse).ToList());
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<DriverResponse>> GetById(int id, CancellationToken cancellationToken)
    {
        var driver = await database.Drivers.AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
        return driver is null ? NotFound() : Ok(ToResponse(driver));
    }

    [HttpPost]
    public async Task<ActionResult<DriverResponse>> Create(DriverRequest request, CancellationToken cancellationToken)
    {
        if (await CheckBus(request.AssignedBusId, null, cancellationToken) is { } problem)
            return problem;

        var driver = new Driver
        {
            FullName = request.FullName.Trim(),
            PhoneNumber = NormalizePhone(request.PhoneNumber),
            IsActive = request.IsActive,
            AssignedBusId = request.AssignedBusId
        };
        database.Drivers.Add(driver);
        await database.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = driver.Id }, ToResponse(driver));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<DriverResponse>> Update(int id, DriverRequest request, CancellationToken cancellationToken)
    {
        var driver = await database.Drivers.FindAsync([id], cancellationToken);
        if (driver is null)
            return NotFound();

        if (await CheckBus(request.AssignedBusId, id, cancellationToken) is { } problem)
            return problem;

        driver.FullName = request.FullName.Trim();
        driver.PhoneNumber = NormalizePhone(request.PhoneNumber);
        driver.IsActive = request.IsActive;
        driver.AssignedBusId = request.AssignedBusId;
        await database.SaveChangesAsync(cancellationToken);
        return Ok(ToResponse(driver));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var driver = await database.Drivers.FindAsync([id], cancellationToken);
        if (driver is null)
            return NotFound();

        database.Drivers.Remove(driver);
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

    /// <summary>Returns an error result when the chosen bus is missing or already taken by another driver.</summary>
    private async Task<ActionResult?> CheckBus(int? busId, int? driverId, CancellationToken cancellationToken)
    {
        if (busId is not int id)
            return null;
        if (!await database.Buses.AnyAsync(bus => bus.Id == id, cancellationToken))
            return BadRequest(new ValidationProblemDetails(new Dictionary<string, string[]> { ["AssignedBusId"] = ["Choose a bus from the list."] }));
        var other = await database.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(item => item.AssignedBusId == id && item.Id != driverId, cancellationToken);
        return other is null
            ? null
            : Conflict(new ProblemDetails
            {
                Status = StatusCodes.Status409Conflict,
                Title = "The bus already has a driver.",
                Detail = $"That bus is already linked to {other.FullName}. Unlink it there first, or choose another bus."
            });
    }

    private static string? NormalizePhone(string? phoneNumber) =>
        string.IsNullOrWhiteSpace(phoneNumber) ? null : phoneNumber.Trim();

    private static DriverResponse ToResponse(Driver driver) =>
        new(driver.Id, driver.FullName, driver.PhoneNumber, driver.IsActive, driver.AssignedBusId);

    public sealed record DriverResponse(int Id, string FullName, string? PhoneNumber, bool IsActive, int? AssignedBusId);
}
