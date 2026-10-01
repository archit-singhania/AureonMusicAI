using System.Collections.Concurrent;

namespace AureonApi.Services;
public record StudioConnection(string ConnectionId, string ProjectId, string Token);
public class StudioConnections
{
    public ConcurrentDictionary<string, StudioConnection> Active { get; } = new();
}
