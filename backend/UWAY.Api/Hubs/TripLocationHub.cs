using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Auth;
using UWAY.Api.Data;
using UWAY.Api.Models;
using UWAY.Api.Services;

namespace UWAY.Api.Hubs;

[Authorize(Policy = "AuthenticatedProjectUser")]
public sealed class TripLocationHub(UwayDbContext database, PassengerAccess passengerAccess) : Hub
{
    public async Task<TripLocationSubscription> JoinTrip(Guid tripId)
    {
        var trip = await database.Trips
            .Include(item => item.Bus)
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == tripId, Context.ConnectionAborted);

        if (trip is null || trip.Status != TripStatus.Started ||
            !trip.StartedAtUtc.HasValue || trip.EndedAtUtc.HasValue || trip.Bus is not { IsActive: true })
            throw new HubException("The trip is not available for live location updates.");

        string groupName;
        if (Context.User?.IsInRole("Admin") == true)
        {
            groupName = TripGroup(tripId);
        }
        else if (Context.User?.IsInRole("Driver") == true)
        {
            if (!int.TryParse(Context.User.FindFirst(UwayClaimTypes.DriverId)?.Value, out var driverId) ||
                trip.DriverId != driverId)
                throw new HubException("The trip is not available for this driver.");

            groupName = TripGroup(tripId);
        }
        else if (Context.User?.IsInRole("Passenger") == true)
        {
            if (await passengerAccess.GetGenderAsync(Context.User!, Context.ConnectionAborted) != trip.Audience)
                throw new HubException("The trip is not available for live location updates.");

            groupName = PassengerTripGroup(tripId);
        }
        else
        {
            throw new HubException("The current role cannot subscribe to trip locations.");
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, groupName, Context.ConnectionAborted);
        return new TripLocationSubscription(tripId, true);
    }

    public Task LeaveTrip(Guid tripId)
    {
        var user = Context.User;
        var groupName = user?.IsInRole("Passenger") == true
            ? PassengerTripGroup(tripId)
            : TripGroup(tripId);
        return Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName, Context.ConnectionAborted);
    }

    public static string TripGroup(Guid tripId) => $"trip-location:{tripId:N}";

    public static string PassengerTripGroup(Guid tripId) => $"trip-location:{tripId:N}:passengers";

    public sealed record TripLocationSubscription(Guid TripId, bool Subscribed);
}
