namespace AureonApi.Models;

public class GenerateRequest
{
    public string Lyrics { get; set; } = string.Empty;
    public string Genre { get; set; } = "rap";
    public string? PreferredEngine { get; set; } = "auto";
    public string? LanguageCode { get; set; } = "en-IN";
    public string? ScaleType { get; set; } = "minor";
    public float RetuneSpeed { get; set; } = 0.1f;
}

public class JobResponse
{
    public string JobId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int Progress { get; set; }
    public string? Error { get; set; }
    public object? Critique { get; set; }
    public bool StemsAvailable { get; set; }
    public bool OutputReady { get; set; }
}

public class GenerateResponse
{
    public string JobId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? PreferredEngine { get; set; }
    public string? LanguageCode { get; set; }
}

public class CachedJob
{
    public string JobId { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string Genre { get; set; } = string.Empty;
    public string LyricsPreview { get; set; } = string.Empty;
}

public class PresetBeat
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Genre { get; set; } = string.Empty;
    public int Bpm { get; set; }
    public string Key { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
}

public class VoicePromptResponse
{
    public string Transcript { get; set; } = string.Empty;
    public string Language { get; set; } = "en-IN";
    public string Source { get; set; } = "sarvam_saaras";
}
