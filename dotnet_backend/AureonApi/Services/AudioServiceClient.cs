using System.Text.Json;
using AureonApi.Models;

namespace AureonApi.Services;

public class AudioServiceClient
{
    private readonly HttpClient _http;
    private readonly ILogger<AudioServiceClient> _logger;

    public AudioServiceClient(HttpClient http, ILogger<AudioServiceClient> logger)
    {
        _http = http;
        _logger = logger;
    }

    public async Task<GenerateResponse?> GenerateAsync(
        Stream beatStream,
        string beatFileName,
        string lyrics,
        string genre,
        Stream? speakerStream = null,
        string? speakerFileName = null)
    {
        using var form = new MultipartFormDataContent();

        var beatContent = new StreamContent(beatStream);
        form.Add(beatContent, "beat", beatFileName);
        form.Add(new StringContent(lyrics), "lyrics");
        form.Add(new StringContent(genre), "genre");

        if (speakerStream != null && speakerFileName != null)
        {
            var spkContent = new StreamContent(speakerStream);
            form.Add(spkContent, "speaker_wav", speakerFileName);
        }

        var response = await _http.PostAsync("/generate", form);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<GenerateResponse>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
    }

    public async Task<JobResponse?> GetStatusAsync(string jobId)
    {
        var response = await _http.GetAsync($"/status/{jobId}");
        if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            return null;
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<JobResponse>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
    }

    public async Task<Stream?> DownloadAsync(string jobId)
    {
        var response = await _http.GetAsync($"/download/{jobId}");
        if (!response.IsSuccessStatusCode)
            return null;
        return await response.Content.ReadAsStreamAsync();
    }

    public async Task<bool> HealthCheckAsync()
    {
        try
        {
            var resp = await _http.GetAsync("/health");
            return resp.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }
}
