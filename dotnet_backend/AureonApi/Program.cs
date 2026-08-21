using AureonApi.Services;
using AureonApi.Hubs;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddSignalR();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "Aureon AI Music API (Supercharged)", Version = "v2" });
});

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials());
});

builder.Services.AddHttpClient<AudioServiceClient>(client =>
{
    var url = builder.Configuration["AudioService:BaseUrl"] ?? "http://localhost:8000";
    client.BaseAddress = new Uri(url);
    client.Timeout = TimeSpan.FromMinutes(10);
});

builder.Services.AddSingleton<JobCacheService>();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();
app.UseCors();

app.MapControllers();
app.MapHub<MusicHub>("/hub/music");

app.MapGet("/", () => Results.Redirect("/swagger"));

app.Run();

