namespace UWAY.Api.Models;

public sealed class RouteStop
{
    public int RouteId { get; set; }
    public Route Route { get; set; } = null!;
    public int StopId { get; set; }
    public Stop Stop { get; set; } = null!;
    public int StopOrder { get; set; }
}
