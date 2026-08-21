using Microsoft.AspNetCore.Mvc;
using AureonApi.Services;

namespace AureonApi.Controllers;

[ApiController]
[Route("api/ultimate")]
public class UltimateController : ControllerBase
{
    private readonly AudioServiceClient _audioService;
    private readonly TimeTravelHistory _history;
    private readonly ILogger<UltimateController> _logger;

    public UltimateController(AudioServiceClient audioService, TimeTravelHistory history, ILogger<UltimateController> logger)
    {
        _audioService = audioService;
        _history = history;
        _logger = logger;
    }

    [HttpPost("history/commit")]
    public IActionResult CommitState([FromForm] string sessionId, [FromForm] string action, [FromBody] Dictionary<string, double> parameters)
    {
        _history.RecordState(sessionId, action, parameters);
        return Ok(new { status = "State recorded in Time Travel history" });
    }

    [HttpGet("history/{sessionId}")]
    public IActionResult GetHistory(string sessionId)
    {
        return Ok(_history.GetHistory(sessionId));
    }

    [HttpPost("denoise")]
    public async Task<IActionResult> DenoiseAudio(IFormFile audio)
    {
        try
        {
            var content = new MultipartFormDataContent();
            using var stream = audio.OpenReadStream();
            content.Add(new StreamContent(stream), "audio", audio.FileName);

            var response = await _audioService.Client.PostAsync("/api/ultimate/denoise", content);
            response.EnsureSuccessStatusCode();

            var fileStream = await response.Content.ReadAsStreamAsync();
            return File(fileStream, "audio/wav", "denoised.wav");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in Denoise");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
