using Microsoft.EntityFrameworkCore;
using Nimbus.Autopilot.Api.Models;

namespace Nimbus.Autopilot.Api.Data;

public class NimbusDbContext : DbContext
{
    public NimbusDbContext(DbContextOptions<NimbusDbContext> options) : base(options)
    {
    }

    public DbSet<Client> Clients { get; set; }
    public DbSet<DeploymentPhase> DeploymentPhases { get; set; }
    public DbSet<TelemetryEvent> TelemetryEvents { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure Client entity
        modelBuilder.Entity<Client>(entity =>
        {
            entity.HasKey(e => e.ClientId);
            entity.HasIndex(e => e.Status);
            entity.HasIndex(e => e.LastSeen);
        });

        // Configure DeploymentPhase entity
        modelBuilder.Entity<DeploymentPhase>(entity =>
        {
            entity.HasKey(e => e.PhaseId);
            entity.HasIndex(e => e.PhaseName).IsUnique();
        });

        // Configure TelemetryEvent entity
        modelBuilder.Entity<TelemetryEvent>(entity =>
        {
            entity.HasKey(e => e.EventId);
            entity.HasIndex(e => e.ClientId);
            entity.HasIndex(e => e.EventTimestamp);
            entity.HasIndex(e => e.PhaseId);
            entity.HasIndex(e => e.Status);

            entity.HasOne(e => e.Client)
                .WithMany(c => c.TelemetryEvents)
                .HasForeignKey(e => e.ClientId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.DeploymentPhase)
                .WithMany(p => p.TelemetryEvents)
                .HasForeignKey(e => e.PhaseId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Seed deployment phases
        modelBuilder.Entity<DeploymentPhase>().HasData(
            new DeploymentPhase { PhaseId = 1, PhaseName = "Device Preparation", PhaseOrder = 1, Description = "Initial device setup and preparation", CreatedAt = DateTime.UtcNow },
            new DeploymentPhase { PhaseId = 2, PhaseName = "Device Setup", PhaseOrder = 2, Description = "Core device configuration", CreatedAt = DateTime.UtcNow },
            new DeploymentPhase { PhaseId = 3, PhaseName = "Account Setup", PhaseOrder = 3, Description = "User account configuration", CreatedAt = DateTime.UtcNow },
            new DeploymentPhase { PhaseId = 4, PhaseName = "Apps Installation", PhaseOrder = 4, Description = "Application deployment", CreatedAt = DateTime.UtcNow },
            new DeploymentPhase { PhaseId = 5, PhaseName = "Policies Application", PhaseOrder = 5, Description = "Security and configuration policies", CreatedAt = DateTime.UtcNow },
            new DeploymentPhase { PhaseId = 6, PhaseName = "Completion", PhaseOrder = 6, Description = "Final deployment stage", CreatedAt = DateTime.UtcNow }
        );
    }
}
