using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nimbus.Autopilot.Api.Data;
using Nimbus.Autopilot.Api.Models;
using Microsoft.AspNetCore.Authorization;

namespace Nimbus.Autopilot.Api.Controllers;

[ApiController]
[Route("api")]
[AllowAnonymous]
public class StatsController : ControllerBase
{
    private readonly NimbusDbContext _context;
    private readonly ILogger<StatsController> _logger;

    public StatsController(NimbusDbContext context, ILogger<StatsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet("stats")]
    public async Task<ActionResult<StatisticsResponse>> GetStatistics()
    {
        try
        {
            // Total clients
            var totalClients = await _context.Clients.CountAsync();

            // Clients by status
            var clientsByStatus = await _context.Clients
                .GroupBy(c => c.Status)
                .Select(g => new StatusCount
                {
                    Status = g.Key,
                    Count = g.Count()
                })
                .ToListAsync();

            // Active deployments (last seen in last hour)
            var oneHourAgo = DateTime.UtcNow.AddHours(-1);
            var activeDeployments = await _context.Clients
                .Where(c => c.LastSeen > oneHourAgo)
                .CountAsync();

            // Average deployment duration for completed deployments
            var completedClients = await _context.Clients
                .Where(c => c.Status == "completed")
                .ToListAsync();

            double? avgDuration = null;
            if (completedClients.Any())
            {
                avgDuration = completedClients
                    .Select(c => (c.LastSeen - c.EnrolledAt).TotalSeconds)
                    .Average();
            }

            return Ok(new StatisticsResponse
            {
                TotalClients = totalClients,
                ClientsByStatus = clientsByStatus,
                ActiveDeployments = activeDeployments,
                AverageDurationSeconds = avgDuration
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching statistics");
            return StatusCode(500, new ErrorResponse
            {
                Error = "Internal Server Error",
                Message = ex.Message
            });
        }
    }

    [HttpGet("deployment-phases")]
    public async Task<ActionResult<DeploymentPhasesResponse>> GetDeploymentPhases()
    {
        try
        {
            var phases = await _context.DeploymentPhases
                .OrderBy(p => p.PhaseOrder)
                .ToListAsync();

            return Ok(new DeploymentPhasesResponse
            {
                Phases = phases
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching deployment phases");
            return StatusCode(500, new ErrorResponse
            {
                Error = "Internal Server Error",
                Message = ex.Message
            });
        }
    }
}
