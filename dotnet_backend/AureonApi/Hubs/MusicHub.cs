using Microsoft.AspNetCore.SignalR;

namespace AureonApi.Hubs;

public interface IMusicClient
{
    Task OnJobProgress(string jobId, string status, int progress, object? critique);
    Task OnJobCompleted(string jobId, string downloadUrl, object? stems);
    Task OnJobFailed(string jobId, string error);
    
    // Multiplayer methods
    Task OnParameterChanged(string userId, string parameter, double value);
    Task OnUserJoinedRoom(string userId);
    Task OnUserLeftRoom(string userId);
}

public class MusicHub : Hub<IMusicClient>
{
    private readonly ILogger<MusicHub> _logger;

    public MusicHub(ILogger<MusicHub> logger)
    {
        _logger = logger;
    }

    public async Task JoinJobGroup(string jobId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "job_{jobId}");
        _logger.LogInformation("Client {ConnectionId} joined job group {JobId}", Context.ConnectionId, jobId);
    }

    public async Task LeaveJobGroup(string jobId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, "job_{jobId}");
    }
    
    // Multiplayer Room Methods
    public async Task JoinStudioRoom(string roomId, string userId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, "room_{roomId}");
        await Clients.OthersInGroup("room_{roomId}").OnUserJoinedRoom(userId);
        _logger.LogInformation("User {UserId} joined studio room {RoomId}", userId, roomId);
    }

    public async Task LeaveStudioRoom(string roomId, string userId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, "room_{roomId}");
        await Clients.OthersInGroup("room_{roomId}").OnUserLeftRoom(userId);
    }

    public async Task BroadcastParameterChange(string roomId, string userId, string parameter, double value)
    {
        // Broadcast DSP parameter tweaks (e.g. tape saturation slider moved)
        await Clients.OthersInGroup("room_{roomId}").OnParameterChanged(userId, parameter, value);
    }
}
