namespace AureonApi.Services;

public class MixState
{
    public string CommitId { get; set; } = Guid.NewGuid().ToString();
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string ActionDescription { get; set; } = string.Empty;
    public Dictionary<string, double> DspParameters { get; set; } = new();
}

public class TimeTravelHistory
{
    private readonly Dictionary<string, List<MixState>> _sessionHistories = new();

    public void RecordState(string sessionId, string action, Dictionary<string, double> parameters)
    {
        if (!_sessionHistories.ContainsKey(sessionId))
        {
            _sessionHistories[sessionId] = new List<MixState>();
        }

        _sessionHistories[sessionId].Add(new MixState
        {
            ActionDescription = action,
            DspParameters = new Dictionary<string, double>(parameters)
        });
    }

    public List<MixState> GetHistory(string sessionId)
    {
        if (_sessionHistories.TryGetValue(sessionId, out var history))
        {
            return history;
        }
        return new List<MixState>();
    }

    public MixState? GetState(string sessionId, string commitId)
    {
        if (_sessionHistories.TryGetValue(sessionId, out var history))
        {
            return history.FirstOrDefault(s => s.CommitId == commitId);
        }
        return null;
    }
}
