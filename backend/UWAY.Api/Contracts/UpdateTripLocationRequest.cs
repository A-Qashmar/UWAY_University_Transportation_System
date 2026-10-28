using System.ComponentModel.DataAnnotations;

namespace UWAY.Api.Contracts;

public sealed class UpdateTripLocationRequest
{
    [Range(typeof(decimal), "-90", "90")]
    public decimal Latitude { get; init; }

    [Range(typeof(decimal), "-180", "180")]
    public decimal Longitude { get; init; }
}
