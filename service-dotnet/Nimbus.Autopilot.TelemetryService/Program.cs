using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.EventLog;

namespace Nimbus.Autopilot.TelemetryService
{
 public class Program
    {
        public static void Main(string[] args)
        {
      CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
     Host.CreateDefaultBuilder(args)
 .UseWindowsService(options =>
      {
    options.ServiceName = "Nimbus Autopilot Telemetry";
                })
          .ConfigureServices((hostContext, services) =>
 {
            // Configure logging to Event Log
 services.Configure<EventLogSettings>(config =>
       {
       config.SourceName = "Nimbus Autopilot Telemetry";
        config.LogName = "Application";
          });

        // Register the worker service
        services.AddHostedService<TelemetryWorker>();
   
        // Register telemetry API client (singleton with own HttpClient)
        services.AddSingleton<ITelemetryApiClient, TelemetryApiClient>();
   
     // Register telemetry collector
          services.AddSingleton<IAutopilotTelemetryCollector, AutopilotTelemetryCollector>();
                    
   // Register state manager
      services.AddSingleton<IStateManager, StateManager>();
     })
          .ConfigureLogging((hostContext, logging) =>
          {
         logging.AddEventLog();
         });
    }
}
