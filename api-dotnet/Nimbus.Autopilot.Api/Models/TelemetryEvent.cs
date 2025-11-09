using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Nimbus.Autopilot.Api.Models;

[Table("telemetry_events")]
public class TelemetryEvent
{
    [Key]
    [Column("event_id")]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int EventId { get; set; }

    [Required]
    [Column("client_id")]
    [MaxLength(255)]
    public string ClientId { get; set; } = string.Empty;

    [Column("phase_id")]
    public int? PhaseId { get; set; }

    [Required]
    [Column("event_type")]
    [MaxLength(100)]
    public string EventType { get; set; } = string.Empty;

    [Required]
    [Column("event_timestamp")]
    public DateTime EventTimestamp { get; set; }

    [Column("progress_percentage")]
    [Range(0, 100)]
    public int? ProgressPercentage { get; set; }

    [Column("status")]
    [MaxLength(50)]
    public string? Status { get; set; }

    [Column("duration_seconds")]
    public int? DurationSeconds { get; set; }

    [Column("error_message")]
    public string? ErrorMessage { get; set; }

    [Column("metadata")]
    public string? Metadata { get; set; }  // JSON stored as string in SQL Server

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("ClientId")]
    public virtual Client? Client { get; set; }

    [ForeignKey("PhaseId")]
    public virtual DeploymentPhase? DeploymentPhase { get; set; }
}
