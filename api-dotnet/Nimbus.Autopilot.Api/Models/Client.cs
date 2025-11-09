using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Nimbus.Autopilot.Api.Models;

[Table("clients")]
public class Client
{
    [Key]
    [Column("client_id")]
    [MaxLength(255)]
    public string ClientId { get; set; } = string.Empty;

    [Column("device_name")]
    [MaxLength(255)]
    public string? DeviceName { get; set; }

    [Column("enrolled_at")]
    public DateTime EnrolledAt { get; set; } = DateTime.UtcNow;

    [Column("last_seen")]
    public DateTime LastSeen { get; set; } = DateTime.UtcNow;

    [Column("deployment_profile")]
    [MaxLength(255)]
    public string? DeploymentProfile { get; set; }

    [Column("status")]
    [MaxLength(50)]
    public string Status { get; set; } = "active";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    public virtual ICollection<TelemetryEvent> TelemetryEvents { get; set; } = new List<TelemetryEvent>();
}
