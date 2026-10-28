using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using UWAY.Api.Data;

#nullable disable

namespace UWAY.Api.Migrations;

[DbContext(typeof(UwayDbContext))]
public sealed class UwayDbContextModelSnapshot : ModelSnapshot
{
    protected override void BuildModel(ModelBuilder modelBuilder)
    {
        modelBuilder.HasAnnotation("ProductVersion", "9.0.1");
        UwayDbContext.ConfigureModel(modelBuilder);
    }
}
