namespace UWAY.Api.Models;

public sealed class Driver
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public bool IsActive { get; set; } = true;

    /// <summary>The bus this driver normally drives (optional). Used to pre-fill trips.</summary>
    public int? AssignedBusId { get; set; }
    public ICollection<Trip> Trips { get; set; } = new List<Trip>();
}
