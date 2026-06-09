using Microsoft.AspNetCore.Mvc;
using AureonApi.Models;
using AureonApi.Services;

namespace AureonApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class MusicController : ControllerBase
{
    private readonly AudioServiceClient _audio;
    private readonly JobCacheService _cache;
    private readonly ILogger<MusicController> _logger;

    private static readonly HashSet<string> AllowedGenres =
        new(StringComparer.OrdinalIgnoreCase) { "trap", "drill", "rap", "rnb", "pop" };

    private static readonly HashSet<string> AllowedBeatExtensions =
        new(StringComparer.OrdinalIgnoreCase) { ".mp3", ".wav", ".flac", ".ogg", ".m4a" };

    public MusicController(
        AudioServiceClient audio,
        JobCacheService cache,
        ILogger<MusicController> logger)
    {
        _audio = audio;
        _cache = cache;
        _logger = logger;
    }

    /// <summary>
    /// Submit a beat + lyrics to generate a song.
    /// </summary>
    [HttpPost("generate")]
    [RequestSizeLimit(50 * 1024 * 1024)] // 50MB
    public async Task<IActionResult> Generate(
        IFormFile beat,
        [FromForm] string lyrics,
        [FromForm] string genre = "rap",
        IFormFile? speakerWav = null)
    {
        if (!AllowedGenres.Contains(genre))
            return BadRequest(new { error = $"Invalid genre. Choose: {string.Join(", ", AllowedGenres)}" });

        if (beat == null || beat.Length == 0)
            return BadRequest(new { error = "Beat file is required." });

        var ext = Path.GetExtension(beat.FileName).ToLowerInvariant();
        if (!AllowedBeatExtensions.Contains(ext))
            return BadRequest(new { error = $"Beat must be one of: {string.Join(", ", AllowedBeatExtensions)}" });

        if (string.IsNullOrWhiteSpace(lyrics))
            return BadRequest(new { error = "Lyrics cannot be empty." });

        try
        {
            await using var beatStream = beat.OpenReadStream();
            Stream? spkStream = speakerWav != null ? speakerWav.OpenReadStream() : null;

            var result = await _audio.GenerateAsync(
                beatStream, beat.FileName,
                lyrics, genre,
                spkStream, speakerWav?.FileName);

            if (result == null)
                return StatusCode(502, new { error = "Audio service returned no response." });

            _cache.Add(new CachedJob
            {
                JobId = result.JobId,
                Status = result.Status,
                Genre = genre,
                LyricsPreview = lyrics.Length > 80 ? lyrics[..80] + "..." : lyrics,
            });

            _logger.LogInformation("Job queued: {JobId}", result.JobId);
            return Ok(result);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Audio service unreachable");
            return StatusCode(503, new { error = "Audio service unavailable. Is the Python service running?" });
        }
    }

    /// <summary>
    /// Poll job status and progress.
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
            return Ok(job);
        }
        catch (HttpRequestException)
        {
            return StatusCode(503, new { error = "Audio service unavailable." });
        }
    }

    /// <summary>
    /// Download the finished MP3.
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
            audioService = audioOk ? "ok" : "unreachable"
        });
    }
}
