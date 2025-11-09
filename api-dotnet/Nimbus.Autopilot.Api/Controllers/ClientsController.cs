using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Nimbus.Autopilot.Api.Data;
using Nimbus.Autopilot.Api.Models;

namespace Nimbus.Autopilot.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClientsController : ControllerBase
{
    private readonly NimbusDbContext _context;
    private readonly ILogger<ClientsController> _logger;

    public ClientsController(NimbusDbContext context, ILogger<ClientsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<ClientsResponse>> GetClients(
        [FromQuery] string? status,
        [FromQuery] int limit = 100,
        [FromQuery] int offset = 0)
    {
        try
        {
            var query = _context.Clients.AsQueryable();

            if (!string.IsNullOrEmpty(status))
            {
                query = query.Where(c => c.Status == status);
            }

            var total = await query.CountAsync();

            var clients = await query
                .OrderByDescending(c => c.LastSeen)
                .Skip(offset)
                .Take(limit)
                .ToListAsync();

            return Ok(new ClientsResponse
            {
                Clients = clients,
                Total = total,
                Limit = limit,
                Offset = offset
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching clients");
            return StatusCode(500, new ErrorResponse
            {
                Error = "Internal Server Error",
                Message = ex.Message
            });
        }
    }

    [HttpGet("{clientId}")]
    public async Task<ActionResult<ClientDetailsResponse>> GetClientDetails(string clientId)
    {
        try
        {
            var client = await _context.Clients.FindAsync(clientId);

            if (client == null)
            {
                return NotFound(new ErrorResponse
                {
                    Error = "Not Found",
                    Message = "Client not found"
                });
            }

            var events = await _context.TelemetryEvents
                .Include(te => te.DeploymentPhase)
                .Where(te => te.ClientId == clientId)
                .OrderByDescending(te => te.EventTimestamp)
                .Select(te => new TelemetryEventDto
                {
                    EventId = te.EventId,
                    ClientId = te.ClientId,
                    PhaseId = te.PhaseId,
                    PhaseName = te.DeploymentPhase != null ? te.DeploymentPhase.PhaseName : null,
                    PhaseOrder = te.DeploymentPhase != null ? te.DeploymentPhase.PhaseOrder : null,
                    EventType = te.EventType,
                    EventTimestamp = te.EventTimestamp,
                    ProgressPercentage = te.ProgressPercentage,
                    Status = te.Status,
                    DurationSeconds = te.DurationSeconds,
                    ErrorMessage = te.ErrorMessage,
                    Metadata = te.Metadata,
                    CreatedAt = te.CreatedAt
                })
                .ToListAsync();

            return Ok(new ClientDetailsResponse
            {
                Client = client,
                Events = events
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching client details");
            return StatusCode(500, new ErrorResponse
            {
                Error = "Internal Server Error",
                Message = ex.Message
            });
        }
    }
}
