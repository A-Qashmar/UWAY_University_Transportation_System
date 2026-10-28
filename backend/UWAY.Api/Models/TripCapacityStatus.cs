namespace UWAY.Api.Models;

public enum TripCapacityStatus
{
    Normal,
    NearlyFull,
    Full,
    OverCapacity
}

public static class TripCapacityRules
{
    public const int NearlyFullThresholdPercent = 80;

    public static TripCapacityStatus Determine(int expectedRiderCount, int busCapacity, bool driverReportedNearlyFull)
    {
        if (expectedRiderCount < 0)
            throw new ArgumentOutOfRangeException(nameof(expectedRiderCount));
        if (busCapacity <= 0)
            throw new ArgumentOutOfRangeException(nameof(busCapacity));

        if (expectedRiderCount > busCapacity)
            return TripCapacityStatus.OverCapacity;
        if (expectedRiderCount == busCapacity)
            return TripCapacityStatus.Full;
        if (driverReportedNearlyFull ||
            (long)expectedRiderCount * 100 >= (long)busCapacity * NearlyFullThresholdPercent)
            return TripCapacityStatus.NearlyFull;

        return TripCapacityStatus.Normal;
    }
}
