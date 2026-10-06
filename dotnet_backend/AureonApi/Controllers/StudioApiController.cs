using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using System.Net.Http.Headers;

namespace AureonApi.Controllers;

/// <summary>One public contract. Python JSON is forwarded without renaming fields.</summary>
[ApiController]
public class StudioApiController(IHttpClientFactory factory, ILogger<StudioApiController> logger) : ControllerBase
{
    [Route("api/v1/{**path}")]
    [AcceptVerbs("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS")]
    [RequestSizeLimit(52 * 1024 * 1024)]
    [PreserveProxyBody]
    public async Task Proxy([FromRoute] string? path, CancellationToken cancellation)
    {
        var client = factory.CreateClient("Audio");
        using var message = new HttpRequestMessage(new HttpMethod(Request.Method), $"/api/v1/{path}{Request.QueryString}");
        if (Request.ContentLength > 0 || Request.Headers.ContainsKey("Transfer-Encoding"))
        {
            message.Content = new StreamContent(Request.Body);
            if (Request.ContentType is { } type) message.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(type);
        }
        foreach (var header in new[] { "Authorization", "Range", "Idempotency-Key", "If-None-Match" })
            if (Request.Headers.TryGetValue(header, out var value)) message.Headers.TryAddWithoutValidation(header, value.ToArray());
        try
        {
            using var upstream = await client.SendAsync(message, HttpCompletionOption.ResponseHeadersRead, cancellation);
            Response.StatusCode = (int)upstream.StatusCode;
            foreach (var header in upstream.Headers.Concat(upstream.Content.Headers))
                if (header.Key is not ("Transfer-Encoding" or "Connection" or "Server")) Response.Headers[header.Key] = header.Value.ToArray();
            await upstream.Content.CopyToAsync(Response.Body, cancellation);
        }
        catch (HttpRequestException error)
        {
            logger.LogWarning(error, "Audio service unavailable");
            Response.StatusCode = 503;
            await Response.WriteAsJsonAsync(new { detail = "The studio service is unavailable. Your saved sessions are preserved." }, cancellation);
        }
        catch (TaskCanceledException) when (!cancellation.IsCancellationRequested)
        {
            Response.StatusCode = 504;
            await Response.WriteAsJsonAsync(new { detail = "The media request timed out. Check Activity before retrying." }, cancellation);
        }
    }
}

/// <summary>Leave multipart streams intact for the upstream upload endpoint.</summary>
public sealed class PreserveProxyBodyAttribute : Attribute, IResourceFilter
{
    public void OnResourceExecuting(ResourceExecutingContext context)
    {
        // MVC's form providers otherwise read Request.Body before Proxy executes.
        context.ValueProviderFactories.RemoveType<FormValueProviderFactory>();
        context.ValueProviderFactories.RemoveType<FormFileValueProviderFactory>();
        context.ValueProviderFactories.RemoveType<JQueryFormValueProviderFactory>();
    }

    public void OnResourceExecuted(ResourceExecutedContext context) { }
}
