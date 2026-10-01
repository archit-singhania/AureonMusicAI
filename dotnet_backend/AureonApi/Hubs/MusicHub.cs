using Microsoft.AspNetCore.SignalR;
using AureonApi.Services;
using System.Text.Json;

namespace AureonApi.Hubs;

public class MusicHub(IHttpClientFactory factory, StudioConnections connections) : Hub
{
    private async Task<JsonElement> Authorized(string route)
    {
        var token = Context.GetHttpContext()?.Request.Query["access_token"].ToString();
        if (string.IsNullOrWhiteSpace(token)) throw new HubException("Sign in to join a session.");
        using var request = new HttpRequestMessage(HttpMethod.Get, route);
        request.Headers.Authorization = new("Bearer", token);
        using var response = await factory.CreateClient("Audio").SendAsync(request);
        if (!response.IsSuccessStatusCode) throw new HubException("You do not have access to this session.");
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return json.RootElement.Clone();
    }
    public override async Task OnConnectedAsync()
    {
        var user = await Authorized("/api/v1/auth/me");
        Context.Items["user_id"] = user.GetProperty("id").GetString();
        Context.Items["name"] = user.GetProperty("name").GetString();
        await base.OnConnectedAsync();
    }
    public async Task JoinProject(string projectId)
    {
        if (!Guid.TryParse(projectId, out _)) throw new HubException("Invalid project.");
        await Authorized($"/api/v1/projects/{projectId}");
        await Groups.AddToGroupAsync(Context.ConnectionId, $"project_{projectId}");
        Context.Items["project"] = projectId;
        connections.Active[Context.ConnectionId] = new(Context.ConnectionId, projectId, Context.GetHttpContext()!.Request.Query["access_token"].ToString());
        await Clients.OthersInGroup($"project_{projectId}").SendAsync("Presence", new { user_id = Context.Items["user_id"], name = Context.Items["name"], connected = true });
    }
    public async Task LeaveProject(string projectId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"project_{projectId}");
        Context.Items.Remove("project");
        connections.Active.TryRemove(Context.ConnectionId, out _);
        await Clients.OthersInGroup($"project_{projectId}").SendAsync("Presence", new { user_id = Context.Items["user_id"], name = Context.Items["name"], connected = false });
    }
    public override async Task OnDisconnectedAsync(Exception? error)
    {
        connections.Active.TryRemove(Context.ConnectionId, out _);
        if (Context.Items.TryGetValue("project", out var value) && value is string project)
            await Clients.OthersInGroup($"project_{project}").SendAsync("Presence", new { user_id = Context.Items["user_id"], name = Context.Items["name"], connected = false });
        await base.OnDisconnectedAsync(error);
    }
}
