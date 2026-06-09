namespace AureonApi.Models;

public class GenerateRequest
{
    public string Lyrics { get; set; } = string.Empty;
    public string Genre { get; set; } = "rap";
}

public class JobResponse
{
    public string JobId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int Progress { get; set; }
    public string? Error { get; set; }
    public object? Critique { get; set; }
    public bool OutputReady { get; set; }
}

public class GenerateResponse
{
    public string JobId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
}

public class CachedJob
{
    public string JobId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string Genre { get; set; } = string.Empty;
    public string LyricsPreview { get; set; } = string.Empty;
}
