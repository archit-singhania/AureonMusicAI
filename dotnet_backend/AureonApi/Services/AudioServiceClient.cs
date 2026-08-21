using System.Net.Http.Headers;
using System.Text.Json;
using AureonApi.Models;

namespace AureonApi.Services;

public class AudioServiceClient
{
    private readonly HttpClient _http;
    public HttpClient Client => _http;
    private readonly ILogger<AudioServiceClient> _logger;
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    public AudioServiceClient(HttpClient http, ILogger<AudioServiceClient> logger)
    {
        _http = http;
        _logger = logger;
    }

    public async Task<GenerateResponse?> GenerateAsync(
        Stream? beatStream,
        string? beatFileName,
        string lyrics,
        string genre,
        Stream? speakerStream = null,
        string? speakerFileName = null,
        string preferredEngine = "auto",
        string languageCode = "en-IN",
        string scaleType = "minor",
        float retuneSpeed = 0.1f)
    {
        using var form = new MultipartFormDataContent();
        form.Add(new StringContent(lyrics), "lyrics");
        form.Add(new StringContent(genre), "genre");
        form.Add(new StringContent(preferredEngine), "preferred_engine");
        form.Add(new StringContent(languageCode), "language_code");
        form.Add(new StringContent(scaleType), "scale_type");
        form.Add(new StringContent(retuneSpeed.ToString()), "retune_speed");

        if (beatStream != null && !string.IsNullOrEmpty(beatFileName))
        {
            var beatContent = new StreamContent(beatStream);
            beatContent.Headers.ContentType = new MediaTypeHeaderValue("audio/mpeg");
            form.Add(beatContent, "beat", beatFileName);
        }

        if (speakerStream != null && speakerFileName != null)
        {
            var spkContent = new StreamContent(speakerStream);
            spkContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
            form.Add(spkContent, "speaker_wav", speakerFileName);
        }

        var response = await _http.PostAsync("/generate", form);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<GenerateResponse>(json, JsonOptions);
    }

    public async Task<JobResponse?> GetStatusAsync(string jobId)
    {
        var response = await _http.GetAsync($"/status/{jobId}");
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            return null;

        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<JobResponse>(json, JsonOptions);
    }

    public async Task<Stream?> DownloadAsync(string jobId)
    {
        var response = await _http.GetAsync($"/download/{jobId}");
        if (!response.IsSuccessStatusCode)
            return null;

        return await response.Content.ReadAsStreamAsync();
    }

    public async Task<Stream?> DownloadStemAsync(string jobId, string stemName)
    {
        var response = await _http.GetAsync($"/download/{jobId}/stem/{stemName}");
        if (!response.IsSuccessStatusCode)
            return null;

        return await response.Content.ReadAsStreamAsync();
    }

    public async Task<List<PresetBeat>> GetPresetBeatsAsync()
    {
        try
        {
            var response = await _http.GetAsync("/api/presets/beats");
            if (!response.IsSuccessStatusCode) return [];
            var json = await response.Content.ReadAsStringAsync();
            return JsonSerializer.Deserialize<List<PresetBeat>>(json, JsonOptions) ?? [];
        }
        catch
        {
            return [];
        }
    }

    public async Task<VoicePromptResponse?> ProcessVoicePromptAsync(Stream audioStream, string fileName, string languageCode = "unknown")
    {
        using var form = new MultipartFormDataContent();
        var audioContent = new StreamContent(audioStream);
        audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        form.Add(audioContent, "voice_audio", fileName);
        form.Add(new StringContent(languageCode), "language_code");

        var response = await _http.PostAsync("/api/voice/prompt", form);
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<VoicePromptResponse>(json, JsonOptions);
    }

    public async Task<bool> HealthCheckAsync()
    {
        try
        {
            var response = await _http.GetAsync("/health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}

