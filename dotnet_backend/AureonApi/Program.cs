using AureonApi.Hubs;
using AureonApi.Services;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddSingleton<StudioConnections>();
builder.Services.AddHttpClient("Audio", client => {
    client.BaseAddress = new Uri(builder.Configuration["AudioService:BaseUrl"] ?? "http://localhost:8000");
    client.Timeout = TimeSpan.FromMinutes(6);
});
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy
    .WithOrigins((builder.Configuration["AllowedOrigins"] ?? "http://localhost:3005,http://localhost:8080").Split(','))
    .AllowAnyHeader().AllowAnyMethod().AllowCredentials()));
builder.Services.AddRateLimiter(options => options.AddPolicy("api", context =>
    RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "local", _ =>
        new FixedWindowRateLimiterOptions { PermitLimit = 180, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })));
builder.Services.AddHostedService<StudioEventRelay>();
var app = builder.Build();
app.UseCors();
app.UseRateLimiter();
app.MapControllers().RequireRateLimiting("api");
app.MapHub<MusicHub>("/hub/music");
app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "aureon-gateway", version = 1 }));
app.Run();
public partial class Program { }
