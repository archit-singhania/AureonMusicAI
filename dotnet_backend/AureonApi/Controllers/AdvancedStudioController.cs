using Microsoft.AspNetCore.Mvc;
using AureonApi.Services;
using AureonApi.Models;

namespace AureonApi.Controllers
{
    [ApiController]
    [Route("api/advanced")]
    public class AdvancedStudioController : ControllerBase
    {
        private readonly AudioServiceClient _audioService;
        private readonly ILogger<AdvancedStudioController> _logger;

        public AdvancedStudioController(AudioServiceClient audioService, ILogger<AdvancedStudioController> logger)
        {
            _audioService = audioService;
            _logger = logger;
        }

        [HttpPost("musicgen")]
        public async Task<IActionResult> GenerateMusicGen([FromForm] string prompt, [FromForm] int duration = 15)
        {
            try
            {
                var content = new MultipartFormDataContent();
                content.Add(new StringContent(prompt), "prompt");
                content.Add(new StringContent(duration.ToString()), "duration");

                var response = await _audioService.Client.PostAsync("/api/studio/advanced/musicgen", content);
                response.EnsureSuccessStatusCode();

                var fileStream = await response.Content.ReadAsStreamAsync();
                return File(fileStream, "audio/wav", "musicgen_generated.wav");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in MusicGen");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("rvc")]
        public async Task<IActionResult> ApplyRVC(IFormFile voiceAudio, [FromForm] string targetVoice = "pop_star", [FromForm] int pitchShift = 0)
        {
            if (voiceAudio == null) return BadRequest("No audio file provided");

            try
            {
                var content = new MultipartFormDataContent();
                using var stream = voiceAudio.OpenReadStream();
                content.Add(new StreamContent(stream), "voice_audio", voiceAudio.FileName);
                content.Add(new StringContent(targetVoice), "target_voice");
                content.Add(new StringContent(pitchShift.ToString()), "pitch_shift");

                var response = await _audioService.Client.PostAsync("/api/studio/advanced/rvc", content);
                response.EnsureSuccessStatusCode();

                var fileStream = await response.Content.ReadAsStreamAsync();
                return File(fileStream, "audio/wav", $"rvc_{targetVoice}.wav");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in RVC");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("cover")]
        public async Task<IActionResult> GenerateCover([FromForm] string prompt, [FromForm] string jobId)
        {
            try
            {
                var content = new MultipartFormDataContent();
                content.Add(new StringContent(prompt), "prompt");
                content.Add(new StringContent(jobId), "job_id");

                var response = await _audioService.Client.PostAsync("/api/studio/advanced/cover", content);
                response.EnsureSuccessStatusCode();

                var fileStream = await response.Content.ReadAsStreamAsync();
                return File(fileStream, "image/jpeg", $"cover_{jobId}.jpg");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in Cover Gen");
                return StatusCode(500, new { error = ex.Message });
            }
        }

        [HttpPost("lyrics")]
        public async Task<IActionResult> GenerateLyrics([FromForm] string prompt, [FromForm] string context = "")
        {
            try
            {
                var content = new MultipartFormDataContent();
                content.Add(new StringContent(prompt), "prompt");
                content.Add(new StringContent(context), "context");

                var response = await _audioService.Client.PostAsync("/api/studio/advanced/lyrics", content);
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadAsStringAsync();
                return Content(result, "application/json");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in Lyrics Gen");
                return StatusCode(500, new { error = ex.Message });
            }
        }
        
        [HttpGet("export/als/{jobId}")]
        public async Task<IActionResult> ExportAls(string jobId)
        {
            try
            {
                var response = await _audioService.Client.GetAsync($"/api/studio/stems/als/{jobId}");
                response.EnsureSuccessStatusCode();

                var fileStream = await response.Content.ReadAsStreamAsync();
                return File(fileStream, "application/gzip", $"Aureon_{jobId}.als");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in ALS Export");
                return StatusCode(500, new { error = ex.Message });
            }
        }
    }
}
