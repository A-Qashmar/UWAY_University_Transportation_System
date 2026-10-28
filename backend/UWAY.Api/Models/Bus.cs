namespace UWAY.Api.Models;

public sealed class Bus
{
    public int Id { get; set; }
    public string FleetNumber { get; set; } = string.Empty;
    public int Capacity { get; set; }
    public bool IsActive { get; set; } = true;
    public ICollection<Trip> Trips { get; set; } = new List<Trip>();
}
