namespace Nimbus.Autopilot.Api.Models;

public class TelemetryRequest
{
    public string ClientId { get; set; } = string.Empty;
    public string? DeviceName { get; set; }
    public string? DeploymentProfile { get; set; }
    public string? PhaseName { get; set; }
    public string EventType { get; set; } = string.Empty;
    public DateTime EventTimestamp { get; set; }
    public int? ProgressPercentage { get; set; }
    public string? Status { get; set; }
    public int? DurationSeconds { get; set; }
    public string? ErrorMessage { get; set; }
    public Dictionary<string, object>? Metadata { get; set; }
}

public class TelemetryResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public int EventId { get; set; }
}

public class HealthResponse
{
    public string Status { get; set; } = string.Empty;
    public string Database { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
    public string? Error { get; set; }
}

public class ClientsResponse
{
    public List<Client> Clients { get; set; } = new();
    public int Total { get; set; }
    public int Limit { get; set; }
    public int Offset { get; set; }
}

public class ClientDetailsResponse
{
    public Client? Client { get; set; }
    public List<TelemetryEventDto> Events { get; set; } = new();
}

public class TelemetryEventDto
{
    public int EventId { get; set; }
    public string ClientId { get; set; } = string.Empty;
    public int? PhaseId { get; set; }
    public string? PhaseName { get; set; }
    public int? PhaseOrder { get; set; }
    public string EventType { get; set; } = string.Empty;
    public DateTime EventTimestamp { get; set; }
    public int? ProgressPercentage { get; set; }
    public string? Status { get; set; }
    public int? DurationSeconds { get; set; }
    public string? ErrorMessage { get; set; }
    public string? Metadata { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? DeviceName { get; set; }
}

public class TelemetryEventsResponse
{
    public List<TelemetryEventDto> Events { get; set; } = new();
    public int Limit { get; set; }
    public int Offset { get; set; }
}

public class DeploymentPhasesResponse
{
    public List<DeploymentPhase> Phases { get; set; } = new();
}

public class StatisticsResponse
{
    public int TotalClients { get; set; }
    public List<StatusCount> ClientsByStatus { get; set; } = new();
    public int ActiveDeployments { get; set; }
    public double? AverageDurationSeconds { get; set; }
}

public class StatusCount
{
    public string Status { get; set; } = string.Empty;
    public int Count { get; set; }
}

public class ErrorResponse
{
    public string Error { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
}
