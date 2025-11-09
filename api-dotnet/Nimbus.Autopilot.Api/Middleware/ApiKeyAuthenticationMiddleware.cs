namespace Nimbus.Autopilot.Api.Middleware;

public class ApiKeyAuthenticationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IConfiguration _configuration;
    private readonly ILogger<ApiKeyAuthenticationMiddleware> _logger;
    private const string API_KEY_HEADER_NAME = "X-API-Key";

    public ApiKeyAuthenticationMiddleware(
        RequestDelegate next,
        IConfiguration configuration,
        ILogger<ApiKeyAuthenticationMiddleware> logger)
    {
        _next = next;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip authentication for health endpoint
        if (context.Request.Path.StartsWithSegments("/api/health"))
        {
            await _next(context);
            return;
        }

        // Skip authentication for Swagger/OpenAPI endpoints in development
        if (context.Request.Path.StartsWithSegments("/swagger") || 
            context.Request.Path.StartsWithSegments("/index.html"))
        {
            await _next(context);
            return;
        }

        // Skip API key check for MVC/Razor Pages routes and Entra AD authentication endpoints
        if (!context.Request.Path.StartsWithSegments("/api") || 
            context.Request.Path.StartsWithSegments("/api/account") ||
            context.Request.Path.StartsWithSegments("/signin-oidc") ||
            context.Request.Path.StartsWithSegments("/signout-oidc"))
        {
            await _next(context);
            return;
        }

        // Allow authenticated users (Entra AD) to access API endpoints
        if (context.User?.Identity?.IsAuthenticated == true)
        {
            await _next(context);
            return;
        }

        // Check if API key is present
        if (!context.Request.Headers.TryGetValue(API_KEY_HEADER_NAME, out var extractedApiKey))
        {
            _logger.LogWarning("API Key not provided in request");
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new
            {
                error = "Unauthorized",
                message = "Invalid or missing API key"
            });
            return;
        }

        var apiKey = _configuration.GetValue<string>("ApiKey");
        if (string.IsNullOrEmpty(apiKey))
        {
            _logger.LogError("API Key not configured");
            context.Response.StatusCode = 500;
            await context.Response.WriteAsJsonAsync(new
            {
                error = "Internal Server Error",
                message = "API authentication not configured"
            });
            return;
        }

        if (!apiKey.Equals(extractedApiKey))
        {
            _logger.LogWarning("Invalid API Key provided");
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new
            {
                error = "Unauthorized",
                message = "Invalid or missing API key"
            });
            return;
        }

        await _next(context);
    }
}
