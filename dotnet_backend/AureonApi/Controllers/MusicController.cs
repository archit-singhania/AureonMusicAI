using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using AureonApi.Models;
using AureonApi.Services;
using AureonApi.Hubs;

namespace AureonApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MusicController : ControllerBase
{
    private readonly AudioServiceClient _audio;
    private readonly JobCacheService _cache;
    private readonly IHubContext<MusicHub, IMusicClient> _hubContext;
    private readonly ILogger<MusicController> _logger;

    private static readonly HashSet<string> AllowedGenres =
        new(StringComparer.OrdinalIgnoreCase) { "trap", "drill", "rap", "rnb", "pop" };

    private static readonly HashSet<string> AllowedBeatExtensions =
        new(StringComparer.OrdinalIgnoreCase) { ".mp3", ".wav", ".flac", ".ogg", ".m4a" };

    public MusicController(
        AudioServiceClient audio,
        JobCacheService cache,
        IHubContext<MusicHub, IMusicClient> hubContext,
        ILogger<MusicController> logger)
    {
        _audio = audio;
        _cache = cache;
        _hubContext = hubContext;
        _logger = logger;
    }

    /// <summary>
    /// Submit a beat + lyrics to generate a song.
    /// </summary>
    [HttpPost("generate")]
    [RequestSizeLimit(50 * 1024 * 1024)] // 50MB
    public async Task<IActionResult> Generate(
        IFormFile? beat,
        [FromForm] string lyrics,
        [FromForm] string genre = "rap",
        [FromForm] string preferredEngine = "auto",
        [FromForm] string languageCode = "en-IN",
        [FromForm] string scaleType = "minor",
        [FromForm] float retuneSpeed = 0.1f,
        IFormFile? speakerWav = null)
    {
        if (!AllowedGenres.Contains(genre))
            return BadRequest(new { error = $"Invalid genre. Choose: {string.Join(", ", AllowedGenres)}" });

        if (string.IsNullOrWhiteSpace(lyrics))
            return BadRequest(new { error = "Lyrics cannot be empty." });

        if (beat != null && beat.Length > 0)
        {
            var ext = Path.GetExtension(beat.FileName).ToLowerInvariant();
            if (!AllowedBeatExtensions.Contains(ext))
                return BadRequest(new { error = $"Beat must be one of: {string.Join(", ", AllowedBeatExtensions)}" });
        }

        try
        {
            Stream? beatStream = beat != null && beat.Length > 0 ? beat.OpenReadStream() : null;
            Stream? spkStream = speakerWav != null && speakerWav.Length > 0 ? speakerWav.OpenReadStream() : null;

            var result = await _audio.GenerateAsync(
                beatStream, beat?.FileName,
                lyrics, genre,
                spkStream, speakerWav?.FileName,
                preferredEngine, languageCode, scaleType, retuneSpeed);

            if (result == null)
                return StatusCode(502, new { error = "Audio service returned no response." });

            _cache.Add(new CachedJob
            {
                JobId = result.JobId,
                Status = result.Status,
                Genre = genre,
                LyricsPreview = lyrics.Length > 80 ? lyrics[..80] + "..." : lyrics,
            });

            _logger.LogInformation("Job queued: {JobId} (engine={Engine}, lang={Lang})", result.JobId, preferredEngine, languageCode);
            return Ok(result);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Audio service unreachable");
            return StatusCode(503, new { error = "Audio service unavailable. Is the Python service running?" });
        }
    }

    /// <summary>
    /// Poll job status and progress (also pushes real-time SignalR event).
    /// </summary>
    [HttpGet("status/{jobId}")]
    public async Task<IActionResult> Status(string jobId)
    {
        try
        {
            var job = await _audio.GetStatusAsync(jobId);
            if (job == null)
                return NotFound(new { error = "Job not found." });

            _cache.UpdateStatus(jobId, job.Status);

            // Broadcast real-time update to connected SignalR clients
            await _hubContext.Clients.Group($"job_{jobId}").OnJobProgress(jobId, job.Status, job.Progress, job.Critique);

            if (job.OutputReady)
            {
                var downloadUrl = $"/api/music/download/{jobId}";
                await _hubContext.Clients.Group($"job_{jobId}").OnJobCompleted(jobId, downloadUrl, null);
            }

            return Ok(job);
        }
        catch (HttpRequestException)
        {
            return StatusCode(503, new { error = "Audio service unavailable." });
        }
    }

    /// <summary>
    /// Download the finished MP3 master.
    /// </summary>
    [HttpGet("download/{jobId}")]
    public async Task<IActionResult> Download(string jobId)
    {
        try
        {
            var stream = await _audio.DownloadAsync(jobId);
            if (stream == null)
                return BadRequest(new { error = "Job not complete or not found." });

            return File(stream, "audio/mpeg", $"aureon_{jobId}.mp3");
        }
        catch (HttpRequestException)
        {
            return StatusCode(503, new { error = "Audio service unavailable." });
        }
    }

    /// <summary>
    /// Download individual separated stems (vocals, drums, bass, other) for Mini-DAW.
    /// </summary>
    [HttpGet("download/{jobId}/stem/{stemName}")]
    public async Task<IActionResult> DownloadStem(string jobId, string stemName)
    {
        try
        {
            var stream = await _audio.DownloadStemAsync(jobId, stemName);
            if (stream == null)
                return NotFound(new { error = $"Stem '{stemName}' not ready or not found." });

            return File(stream, "audio/wav", $"aureon_{jobId}_{stemName}.wav");
        }
        catch (HttpRequestException)
        {
            return StatusCode(503, new { error = "Audio service unavailable." });
        }
    }

    /// <summary>
    /// Get curated preset beats library.
    /// </summary>
    [HttpGet("presets")]
    public async Task<IActionResult> GetPresetBeats()
    {
        var beats = await _audio.GetPresetBeatsAsync();
        return Ok(beats);
    }

    /// <summary>
    /// Transcribe voice recording into lyrics / musical prompt via Sarvam Saaras AI.
    /// </summary>
    [HttpPost("voice/prompt")]
    public async Task<IActionResult> VoicePrompt(IFormFile voiceAudio, [FromForm] string languageCode = "unknown")
    {
        if (voiceAudio == null || voiceAudio.Length == 0)
            return BadRequest(new { error = "Audio file is required." });

        try
        {
            await using var stream = voiceAudio.OpenReadStream();
            var res = await _audio.ProcessVoicePromptAsync(stream, voiceAudio.FileName, languageCode);
            return Ok(res);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Voice prompt failed");
            return StatusCode(503, new { error = "Voice processing service unavailable." });
        }
    }

    /// <summary>
    /// List all jobs submitted in this session.
    /// </summary>
    [HttpGet("jobs")]
    public IActionResult ListJobs() => Ok(_cache.GetAll());

    /// <summary>
    /// Health check — pings .NET and Python service.
    /// </summary>
    [HttpGet("health")]
    public async Task<IActionResult> Health()
    {
        var audioOk = await _audio.HealthCheckAsync();
        return Ok(new
        {
            dotnet = "ok",
            audioService = audioOk ? "ok" : "unreachable",
            realtimeHub = "/hub/music"
        });
    }
}
