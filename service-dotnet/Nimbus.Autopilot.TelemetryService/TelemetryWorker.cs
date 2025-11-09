using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Nimbus.Autopilot.TelemetryService
{
    public class TelemetryWorker : BackgroundService
    {
        private readonly ILogger<TelemetryWorker> _logger;
        private readonly IConfiguration _configuration;
        private readonly ITelemetryApiClient _apiClient;
private readonly IAutopilotTelemetryCollector _telemetryCollector;
    private readonly IStateManager _stateManager;
        private readonly int _intervalSeconds;
    private readonly int _heartbeatIntervalSeconds;

        private DateTime _lastHeartbeat;
        private string? _lastPhase;
        private int _lastProgress = -1;

    public TelemetryWorker(
      ILogger<TelemetryWorker> logger,
            IConfiguration configuration,
            ITelemetryApiClient apiClient,
      IAutopilotTelemetryCollector telemetryCollector,
   IStateManager stateManager)
        {
          _logger = logger;
  _configuration = configuration;
       _apiClient = apiClient;
            _telemetryCollector = telemetryCollector;
            _stateManager = stateManager;

   var intervalValue = configuration["TelemetrySettings:IntervalSeconds"];
 _intervalSeconds = !string.IsNullOrEmpty(intervalValue) ? int.Parse(intervalValue) : 30;
  
   var heartbeatValue = configuration["TelemetrySettings:HeartbeatIntervalSeconds"];
    _heartbeatIntervalSeconds = !string.IsNullOrEmpty(heartbeatValue) ? int.Parse(heartbeatValue) : 300;
   
            _lastHeartbeat = DateTime.UtcNow;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
   _logger.LogInformation("Nimbus Autopilot Telemetry Service starting at: {time}", DateTimeOffset.Now);
       
 var deploymentStartTime = _stateManager.GetDeploymentStartTime();
      if (deploymentStartTime == DateTime.MinValue)
  {
             deploymentStartTime = DateTime.UtcNow;
 _stateManager.SaveDeploymentStartTime(deploymentStartTime);
            }

      _logger.LogInformation("Deployment start time: {time}", deploymentStartTime);

   while (!stoppingToken.IsCancellationRequested)
   {
             try
                {
            // Send heartbeat if interval elapsed
            if ((DateTime.UtcNow - _lastHeartbeat).TotalSeconds >= _heartbeatIntervalSeconds)
        {
 await SendHeartbeatAsync(deploymentStartTime, stoppingToken);
  _lastHeartbeat = DateTime.UtcNow;
        }

           // Collect current telemetry data
    var telemetryData = _telemetryCollector.CollectTelemetry();
            
         // Calculate duration from deployment start
             var durationSeconds = (int)(DateTime.UtcNow - deploymentStartTime).TotalSeconds;
           telemetryData.DurationSeconds = durationSeconds;

             // Determine if we should send telemetry
        bool shouldSend = ShouldSendTelemetry(telemetryData);

         if (shouldSend)
        {
  _logger.LogInformation(
  "Sending telemetry: {eventType} - Phase: {phase} - Progress: {progress}%",
   telemetryData.EventType,
 telemetryData.PhaseName,
    telemetryData.ProgressPercentage);

var success = await _apiClient.SendTelemetryAsync(telemetryData, stoppingToken);

              if (success)
    {
  _lastPhase = telemetryData.PhaseName;
     _lastProgress = telemetryData.ProgressPercentage;
      _stateManager.SaveLastPhase(_lastPhase);
      _stateManager.SaveLastProgress(_lastProgress);
            }
        }
  else
       {
        _logger.LogDebug("No significant change, skipping telemetry submission");
          }

// Check if deployment is complete
    if (telemetryData.Status == "completed")
          {
  _logger.LogInformation("Deployment completed. Entering maintenance mode...");

     // Send final completion event
             telemetryData.EventType = "completion";
              await _apiClient.SendTelemetryAsync(telemetryData, stoppingToken);

  // Enter maintenance mode with longer intervals
  await MaintenanceModeAsync(deploymentStartTime, stoppingToken);
    break;
}

           await Task.Delay(TimeSpan.FromSeconds(_intervalSeconds), stoppingToken);
 }
    catch (Exception ex)
            {
    _logger.LogError(ex, "Error in telemetry collection loop");
         await Task.Delay(TimeSpan.FromSeconds(_intervalSeconds), stoppingToken);
      }
            }

            _logger.LogInformation("Nimbus Autopilot Telemetry Service stopping at: {time}", DateTimeOffset.Now);
        }

  private bool ShouldSendTelemetry(TelemetryData data)
        {
            return data.PhaseName != _lastPhase ||
     Math.Abs(data.ProgressPercentage - _lastProgress) >= 5 ||
   data.Status == "completed" ||
          data.Status == "error";
        }

 private async Task SendHeartbeatAsync(DateTime deploymentStartTime, CancellationToken cancellationToken)
        {
      try
        {
   var heartbeat = new TelemetryData
   {
       ClientId = _telemetryCollector.GetClientId(),
     DeviceName = Environment.MachineName,
     DeploymentProfile = _configuration["TelemetrySettings:DeploymentProfile"] ?? "Standard",
   PhaseName = "Service Running",
   EventType = "heartbeat",
    EventTimestamp = DateTime.UtcNow,
      ProgressPercentage = 0,
   Status = "active",
        DurationSeconds = (int)(DateTime.UtcNow - deploymentStartTime).TotalSeconds,
   Metadata = new System.Collections.Generic.Dictionary<string, object>
        {
  { "service_uptime_seconds", (int)(DateTime.UtcNow - deploymentStartTime).TotalSeconds },
            { "os_version", Environment.OSVersion.Version.ToString() }
    }
      };

    await _apiClient.SendTelemetryAsync(heartbeat, cancellationToken);
     _logger.LogDebug("Heartbeat sent successfully");
 }
     catch (Exception ex)
      {
      _logger.LogWarning(ex, "Failed to send heartbeat");
        }
    }

  private async Task MaintenanceModeAsync(DateTime deploymentStartTime, CancellationToken stoppingToken)
      {
            _logger.LogInformation("Entering maintenance mode - heartbeat every 10 minutes");

         while (!stoppingToken.IsCancellationRequested)
 {
                await Task.Delay(TimeSpan.FromMinutes(10), stoppingToken);
           await SendHeartbeatAsync(deploymentStartTime, stoppingToken);
      _logger.LogDebug("Maintenance mode - heartbeat sent");
            }
}
    }
}
