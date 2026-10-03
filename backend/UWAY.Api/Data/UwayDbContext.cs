using Microsoft.EntityFrameworkCore;

namespace UWAY.Api.Data;

/// <summary>Database entry point. Feature entities and migrations are added with the Phase 3 domain work.</summary>
public sealed class UwayDbContext(DbContextOptions<UwayDbContext> options) : DbContext(options) { }
