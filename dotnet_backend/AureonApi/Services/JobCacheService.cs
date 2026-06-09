using System.Collections.Concurrent;
using AureonApi.Models;

namespace AureonApi.Services;

public class JobCacheService
{
    private readonly ConcurrentDictionary<string, CachedJob> _jobs = new();

    public void Add(CachedJob job) => _jobs[job.JobId] = job;

    public CachedJob? Get(string jobId) =>
        _jobs.TryGetValue(jobId, out var job) ? job : null;

    public IEnumerable<CachedJob> GetAll() =>
        _jobs.Values.OrderByDescending(j => j.CreatedAt);

    public void UpdateStatus(string jobId, string status)
    {
        if (_jobs.TryGetValue(jobId, out var job))
            job.Status = status;
    }
}
