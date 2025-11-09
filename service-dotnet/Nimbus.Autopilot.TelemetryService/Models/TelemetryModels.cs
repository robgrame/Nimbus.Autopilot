using System;
using System.Collections.Generic;

namespace Nimbus.Autopilot.TelemetryService
{
    public class TelemetryData
    {
        public string ClientId { get; set; } = string.Empty;
        public string DeviceName { get; set; } = string.Empty;
        public string DeploymentProfile { get; set; } = string.Empty;
    public string PhaseName { get; set; } = string.Empty;
    public string EventType { get; set; } = string.Empty;
   public DateTime EventTimestamp { get; set; }
        public int ProgressPercentage { get; set; }
        public string Status { get; set; } = string.Empty;
     public int DurationSeconds { get; set; }
     public string? ErrorMessage { get; set; }
      public Dictionary<string, object>? Metadata { get; set; }
    }

    public class PhaseInfo
    {
 public string Phase { get; set; } = string.Empty;
        public int Progress { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? Error { get; set; }
    }

    public class EspStatus
    {
public bool IsActive { get; set; }
        public int? EnrollmentState { get; set; }
        public int? LastError { get; set; }
        public string? Error { get; set; }
    }
}
