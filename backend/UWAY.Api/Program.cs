using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;
using UWAY.Api.Data;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

builder.Services.AddControllers();
builder.Services.AddHealthChecks();
builder.Services.AddDbContext<UwayDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("UwayDatabase")));
builder.Services.AddAuthentication(); // Provider is intentionally selected during the authentication feature phase.
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("PassengerOnly", policy => policy.RequireRole("Passenger"));
    options.AddPolicy("DriverOnly", policy => policy.RequireRole("Driver"));
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"));
});
builder.Services.AddCors(options => options.AddPolicy("LocalClients", policy => policy
    .WithOrigins("http://localhost:5173")
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();
app.UseCors("LocalClients");
app.UseAuthentication();
app.UseAuthorization();
app.MapHealthChecks("/health");
app.MapControllers();
app.Run();

public partial class Program { }
