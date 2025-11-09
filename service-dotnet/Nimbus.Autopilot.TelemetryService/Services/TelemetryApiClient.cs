using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Nimbus.Autopilot.TelemetryService
{
    public interface ITelemetryApiClient
    {
  Task<bool> SendTelemetryAsync(TelemetryData data, CancellationToken cancellationToken);
    }

    public class TelemetryApiClient : ITelemetryApiClient
  {
    private readonly HttpClient _httpClient;
        private readonly ILogger<TelemetryApiClient> _logger;
        private readonly string _apiEndpoint;
     private readonly string _apiKey;
    private readonly int _maxRetries;

  public TelemetryApiClient(
 HttpClient httpClient,
            ILogger<TelemetryApiClient> logger,
 IConfiguration configuration)
        {
 _httpClient = httpClient;
     _logger = logger;
      _apiEndpoint = configuration.GetValue<string>("TelemetrySettings:ApiEndpoint")
       ?? throw new ArgumentNullException("ApiEndpoint configuration is required");
_apiKey = configuration.GetValue<string>("TelemetrySettings:ApiKey")
     ?? throw new ArgumentNullException("ApiKey configuration is required");
        _maxRetries = configuration.GetValue<int>("TelemetrySettings:MaxRetries", 3);

         _httpClient.Timeout = TimeSpan.FromSeconds(30);
        }

        public async Task<bool> SendTelemetryAsync(TelemetryData data, CancellationToken cancellationToken)
        {
            return await SendTelemetryWithRetryAsync(data, 0, cancellationToken);
        }

private async Task<bool> SendTelemetryWithRetryAsync(
    TelemetryData data,
            int retryCount,
     CancellationToken cancellationToken)
        {
        try
{
       var requestData = new
        {
      client_id = data.ClientId,
device_name = data.DeviceName,
 deployment_profile = data.DeploymentProfile,
phase_name = data.PhaseName,
           event_type = data.EventType,
     event_timestamp = data.EventTimestamp.ToString("yyyy-MM-ddTHH:mm:ssZ"),
     progress_percentage = data.ProgressPercentage,
         status = data.Status,
       duration_seconds = data.DurationSeconds,
  error_message = data.ErrorMessage,
      metadata = data.Metadata
            };

    var json = JsonConvert.SerializeObject(requestData);
          var content = new StringContent(json, Encoding.UTF8, "application/json");

     var request = new HttpRequestMessage(HttpMethod.Post, $"{_apiEndpoint}/api/telemetry")
     {
      Content = content
       };

                request.Headers.Add("X-API-Key", _apiKey);

       var response = await _httpClient.SendAsync(request, cancellationToken);

      if (response.IsSuccessStatusCode)
        {
        var responseBody = await response.Content.ReadAsStringAsync();
var result = JsonConvert.DeserializeObject<dynamic>(responseBody);
          _logger.LogInformation("Telemetry sent successfully. Event ID: {eventId}", result?.event_id);
       return true;
    }
 else
       {
     _logger.LogWarning(
    "Failed to send telemetry. Status: {status}, Reason: {reason}",
   response.StatusCode,
   response.ReasonPhrase);
    return false;
       }
   }
       catch (Exception ex)
  {
          _logger.LogError(ex, "Error sending telemetry (Attempt {attempt}/{maxRetries})",
    retryCount + 1, _maxRetries);

   if (retryCount < _maxRetries)
   {
     var backoffSeconds = Math.Pow(2, retryCount);
   _logger.LogInformation("Retrying in {seconds} seconds...", backoffSeconds);
await Task.Delay(TimeSpan.FromSeconds(backoffSeconds), cancellationToken);
       return await SendTelemetryWithRetryAsync(data, retryCount + 1, cancellationToken);
       }

    return false;
            }
  }
    }
}
