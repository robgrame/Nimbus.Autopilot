using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using Nimbus.Autopilot.Api.Data;
using Nimbus.Autopilot.Api.Models;
using Nimbus.Autopilot.Api.Hubs;

namespace Nimbus.Autopilot.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TelemetryController : ControllerBase
{
    private readonly NimbusDbContext _context;
    private readonly ILogger<TelemetryController> _logger;
    private readonly IHubContext<TelemetryHub> _hubContext;

    public TelemetryController(
        NimbusDbContext context, 
        ILogger<TelemetryController> logger,
        IHubContext<TelemetryHub> hubContext)
    {
        _context = context;
        _logger = logger;
        _hubContext = hubContext;
    }

    [HttpPost]
    public async Task<ActionResult<TelemetryResponse>> IngestTelemetry([FromBody] TelemetryRequest request)
    {
        try
        {
            // Validate required fields
            if (string.IsNullOrEmpty(request.ClientId) || 
                string.IsNullOrEmpty(request.EventType))
            {
                return BadRequest(new ErrorResponse
                {
                    Error = "Bad Request",
                    Message = "Missing required field: client_id or event_type"
                });
            }

            // Upsert client record
            var client = await _context.Clients.FindAsync(request.ClientId);
            if (client == null)
            {
                client = new Client
                {
                    ClientId = request.ClientId,
                    DeviceName = request.DeviceName,
                    DeploymentProfile = request.DeploymentProfile,
                    EnrolledAt = request.EventTimestamp,
                    LastSeen = request.EventTimestamp
                };
                _context.Clients.Add(client);
            }
            else
            {
                client.DeviceName = request.DeviceName ?? client.DeviceName;
                client.DeploymentProfile = request.DeploymentProfile ?? client.DeploymentProfile;
                client.LastSeen = request.EventTimestamp;
                client.UpdatedAt = DateTime.UtcNow;
            }

            // Get phase_id if phase_name is provided
            int? phaseId = null;
            if (!string.IsNullOrEmpty(request.PhaseName))
            {
                var phase = await _context.DeploymentPhases
                    .FirstOrDefaultAsync(p => p.PhaseName == request.PhaseName);
                if (phase != null)
                {
                    phaseId = phase.PhaseId;
                }
            }

            // Insert telemetry event
            var telemetryEvent = new TelemetryEvent
            {
                ClientId = request.ClientId,
                PhaseId = phaseId,
                EventType = request.EventType,
                EventTimestamp = request.EventTimestamp,
                ProgressPercentage = request.ProgressPercentage,
                Status = request.Status,
                DurationSeconds = request.DurationSeconds,
                ErrorMessage = request.ErrorMessage,
                Metadata = request.Metadata != null ? JsonConvert.SerializeObject(request.Metadata) : null
            };

            _context.TelemetryEvents.Add(telemetryEvent);
            await _context.SaveChangesAsync();

            // Broadcast update to all connected clients via SignalR
            await _hubContext.Clients.All.SendAsync("ReceiveTelemetryUpdate", new
            {
                event_id = telemetryEvent.EventId,
                client_id = request.ClientId,
                device_name = request.DeviceName,
                phase_name = request.PhaseName,
                event_type = request.EventType,
                event_timestamp = request.EventTimestamp,
                progress_percentage = request.ProgressPercentage,
                status = request.Status,
                duration_seconds = request.DurationSeconds,
                error_message = request.ErrorMessage
            });

            return Created($"/api/telemetry/{telemetryEvent.EventId}", new TelemetryResponse
            {
                Success = true,
                Message = "Telemetry data received",
                EventId = telemetryEvent.EventId
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error ingesting telemetry");
            return StatusCode(500, new ErrorResponse
            {
                Error = "Internal Server Error",
                Message = ex.Message
            });
        }
    }

    [HttpGet]
    public async Task<ActionResult<TelemetryEventsResponse>> QueryTelemetry(
        [FromQuery] string? client_id,
        [FromQuery] string? phase_name,
        [FromQuery] string? status,
        [FromQuery] DateTime? from_date,
        [FromQuery] DateTime? to_date,
        [FromQuery] int limit = 100,
        [FromQuery] int offset = 0)
    {
        try
        {
            var query = _context.TelemetryEvents
                .Include(te => te.DeploymentPhase)
                .Include(te => te.Client)
                .AsQueryable();

            if (!string.IsNullOrEmpty(client_id))
            {
                query = query.Where(te => te.ClientId == client_id);
            }

            if (!string.IsNullOrEmpty(phase_name))
            {
                query = query.Where(te => te.DeploymentPhase != null && te.DeploymentPhase.PhaseName == phase_name);
            }

            if (!string.IsNullOrEmpty(status))
            {
                query = query.Where(te => te.Status == status);
            }

            if (from_date.HasValue)
            {
                query = query.Where(te => te.EventTimestamp >= from_date.Value);
            }

            if (to_date.HasValue)
            {
                query = query.Where(te => te.EventTimestamp <= to_date.Value);
            }

            var events = await query
                .OrderByDescending(te => te.EventTimestamp)
                .Skip(offset)
                .Take(limit)
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
                    CreatedAt = te.CreatedAt,
                    DeviceName = te.Client != null ? te.Client.DeviceName : null
                })
                .ToListAsync();

            return Ok(new TelemetryEventsResponse
            {
                Events = events,
                Limit = limit,
                Offset = offset
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error querying telemetry");
            return StatusCode(500, new ErrorResponse
            {
                Error = "Internal Server Error",
                Message = ex.Message
            });
        }
    }
}
