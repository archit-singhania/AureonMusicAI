using AureonApi.Hubs;
using Microsoft.AspNetCore.SignalR;
using System.Text.Json;

namespace AureonApi.Services;

public class StudioEventRelay(IHttpClientFactory factory, IConfiguration config, IHubContext<MusicHub> hub, StudioConnections connections, ILogger<StudioEventRelay> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stop)
    {
        var key = config["AUREON_INTERNAL_KEY"];
        if (string.IsNullOrWhiteSpace(key)) { logger.LogInformation("Internal event relay disabled; authenticated client replay remains available."); return; }
        long cursor = 0;
        while (!stop.IsCancellationRequested)
        {
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Get, $"/internal/events?after={cursor}");
                request.Headers.Add("X-Aureon-Internal-Key", key);
                using var response = await factory.CreateClient("Audio").SendAsync(request, stop);
                response.EnsureSuccessStatusCode();
                using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(stop));
                foreach (var item in json.RootElement.EnumerateArray())
                {
                    cursor = item.GetProperty("event_id").GetInt64();
                    var project = item.GetProperty("project_id").GetString();
                    foreach (var connection in connections.Active.Values.Where(c => c.ProjectId == project))
                    {
                        using var access = new HttpRequestMessage(HttpMethod.Get, $"/api/v1/projects/{project}");
                        access.Headers.Authorization = new("Bearer", connection.Token);
                        using var allowed = await factory.CreateClient("Audio").SendAsync(access, stop);
                        if (allowed.IsSuccessStatusCode)
                            await hub.Clients.Client(connection.ConnectionId).SendAsync("StudioEvent", item.Clone(), stop);
                        else
                        {
                            connections.Active.TryRemove(connection.ConnectionId, out _);
                            await hub.Clients.Client(connection.ConnectionId).SendAsync("SessionAccessRevoked", stop);
                        }
                    }
                }
            }
            catch (Exception error) when (!stop.IsCancellationRequested) { logger.LogDebug(error, "Waiting for event outbox"); }
            await Task.Delay(700, stop);
        }
    }
}
