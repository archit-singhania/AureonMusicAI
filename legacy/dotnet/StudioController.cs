using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using AureonApi.Services;

namespace AureonApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StudioController : ControllerBase
{
    private readonly HttpClient _http;
    private readonly ILogger<StudioController> _logger;
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    public StudioController(HttpClient http, IConfiguration config, ILogger<StudioController> logger)
    {
        _http = http;
        var url = config["AudioService:BaseUrl"] ?? "http://localhost:8000";
        _http.BaseAddress = new Uri(url);
        _logger = logger;
    }

    /// <summary>
    /// Remix a master track through the Studio DSP Effects Rack.
    /// </summary>
    [HttpPost("remix")]
    public async Task<IActionResult> Remix(
        [FromForm] string jobId,
        [FromForm] float saturation = 0.25f,
        [FromForm] float delayMs = 180.0f,
        [FromForm] float delayFeedback = 0.30f,
        [FromForm] float delayMix = 0.20f,
        [FromForm] float stereoWidth = 0.60f,
        [FromForm] float deEsser = 0.40f)
    {
        using var form = new MultipartFormDataContent
        {
            { new StringContent(jobId), "job_id" },
            { new StringContent(saturation.ToString()), "saturation" },
            { new StringContent(delayMs.ToString()), "delay_ms" },
            { new StringContent(delayFeedback.ToString()), "delay_feedback" },
            { new StringContent(delayMix.ToString()), "delay_mix" },
            { new StringContent(stereoWidth.ToString()), "stereo_width" },
            { new StringContent(deEsser.ToString()), "de_esser" }
        };

        try
        {
            var res = await _http.PostAsync("/api/studio/remix", form);
            res.EnsureSuccessStatusCode();
            var json = await res.Content.ReadAsStringAsync();
            return Ok(JsonDocument.Parse(json).RootElement);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Remix DSP processing failed");
            return StatusCode(503, new { error = "Effects rack processing unavailable" });
        }
    }

    /// <summary>
    /// Download a ZIP package of all 4 stems for DAW import.
    /// </summary>
    [HttpGet("stems/zip/{jobId}")]
    public async Task<IActionResult> DownloadStemsZip(string jobId)
    {
        try
        {
            var stream = await _http.GetStreamAsync($"/api/studio/stems/zip/{jobId}");
            return File(stream, "application/zip", $"aureon_{jobId}_stems.zip");
        }
        catch (HttpRequestException)
        {
            return NotFound(new { error = "Stems zip not available or job incomplete" });
        }
    }

    /// <summary>
    /// Generate a 9:16 vertical MP4 video for TikTok and Instagram Reels.
    /// </summary>
    [HttpPost("video/{jobId}")]
    public async Task<IActionResult> GenerateVideo(string jobId, [FromForm] string genre = "trap")
    {
        using var form = new MultipartFormDataContent { { new StringContent(genre), "genre" } };
        try
        {
            var res = await _http.PostAsync($"/api/studio/video/{jobId}", form);
            if (!res.IsSuccessStatusCode)
                return StatusCode((int)res.StatusCode, new { error = "Video generation failed" });

            var stream = await res.Content.ReadAsStreamAsync();
            return File(stream, "video/mp4", $"aureon_{jobId}_reels.mp4");
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Video generation request failed");
            return StatusCode(503, new { error = "Video generation service unavailable" });
        }
    }

    /// <summary>
    /// Conversational AI Studio Mixing Engineer Copilot.
    /// </summary>
    [HttpPost("copilot")]
    public async Task<IActionResult> ChatCopilot([FromForm] string prompt)
    {
        using var form = new MultipartFormDataContent { { new StringContent(prompt), "prompt" } };
        try
        {
            var res = await _http.PostAsync("/api/studio/copilot", form);
            res.EnsureSuccessStatusCode();
            var json = await res.Content.ReadAsStringAsync();
            return Ok(JsonDocument.Parse(json).RootElement);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Mixing copilot service unreachable");
            return StatusCode(503, new { error = "AI copilot unavailable" });
        }
    }

    /// <summary>
    /// Generate algorithmic 808 and drum patterns.
    /// </summary>
    [HttpPost("drums/generate")]
    public async Task<IActionResult> GenerateDrums([FromForm] int bpm = 140, [FromForm] string genre = "trap")
    {
        using var form = new MultipartFormDataContent
        {
            { new StringContent(bpm.ToString()), "bpm" },
            { new StringContent(genre), "genre" }
        };

        try
        {
            var res = await _http.PostAsync("/api/studio/drums/generate", form);
            if (!res.IsSuccessStatusCode)
                return StatusCode((int)res.StatusCode, new { error = "Drum generation failed" });

            var stream = await res.Content.ReadAsStreamAsync();
            return File(stream, "audio/wav", $"aureon_drums_{bpm}bpm.wav");
        }
        catch (HttpRequestException)
        {
            return StatusCode(503, new { error = "Drum synthesizer unavailable" });
        }
    }

    /// <summary>
    /// Get community showcase feed.
    /// </summary>
    [HttpGet("community")]
    public IActionResult GetCommunityFeed()
    {
        var communityTracks = new[]
        {
            new { Id = "comm_1", Title = "Midnight Cyber 808", Artist = "DJ NeonFlux", Genre = "Trap", Likes = 142, Duration = "0:32" },
            new { Id = "comm_2", Title = "South London Drill Heat", Artist = "VocalistPrime", Genre = "Drill", Likes = 98, Duration = "0:28" },
            new { Id = "comm_3", Title = "Monsoon Velvet Rain", Artist = "AuraVoice", Genre = "R&B", Likes = 215, Duration = "0:45" },
            new { Id = "comm_4", Title = "Shibuya Retro Sunset", Artist = "SynthWaveMaster", Genre = "Pop", Likes = 180, Duration = "0:36" }
        };
        return Ok(communityTracks);
    }
}

