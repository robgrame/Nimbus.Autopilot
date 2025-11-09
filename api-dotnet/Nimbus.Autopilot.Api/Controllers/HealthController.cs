using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nimbus.Autopilot.Api.Data;
using Nimbus.Autopilot.Api.Models;
using Microsoft.AspNetCore.Authorization;

namespace Nimbus.Autopilot.Api.Controllers;

[ApiController]
[Route("api")]
[AllowAnonymous]
public class HealthController : ControllerBase
{
    private readonly NimbusDbContext _context;
    private readonly ILogger<HealthController> _logger;

    public HealthController(NimbusDbContext context, ILogger<HealthController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet("health")]
    public async Task<ActionResult<HealthResponse>> GetHealth()
    {
        try
        {
            // Test database connectivity
            await _context.Database.CanConnectAsync();

            return Ok(new HealthResponse
            {
                Status = "healthy",
                Database = "connected",
                Timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check failed");
            return StatusCode(503, new HealthResponse
            {
                Status = "unhealthy",
                Database = "disconnected",
                Error = ex.Message,
                Timestamp = DateTime.UtcNow
            });
        }
    }
}
