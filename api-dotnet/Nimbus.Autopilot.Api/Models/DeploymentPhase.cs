using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Nimbus.Autopilot.Api.Models;

[Table("deployment_phases")]
public class DeploymentPhase
{
    [Key]
    [Column("phase_id")]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int PhaseId { get; set; }

    [Required]
    [Column("phase_name")]
    [MaxLength(100)]
    public string PhaseName { get; set; } = string.Empty;

    [Column("phase_order")]
    public int PhaseOrder { get; set; }

    [Column("description")]
    public string? Description { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    public virtual ICollection<TelemetryEvent> TelemetryEvents { get; set; } = new List<TelemetryEvent>();
}
