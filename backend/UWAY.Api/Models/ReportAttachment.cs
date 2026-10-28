namespace UWAY.Api.Models;

/// <summary>A photo or video attached to a report. The file itself is stored in the database.</summary>
public sealed class ReportAttachment
{
    public Guid Id { get; set; }
    public Guid ReportId { get; set; }
    public Report Report { get; set; } = null!;
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public byte[] Data { get; set; } = [];
    public DateTimeOffset CreatedAtUtc { get; set; }
}
