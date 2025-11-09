using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;

namespace Nimbus.Autopilot.TelemetryService
{
    public interface IAutopilotTelemetryCollector
    {
     TelemetryData CollectTelemetry();
        string GetClientId();
    }

    public class AutopilotTelemetryCollector : IAutopilotTelemetryCollector
    {
        private readonly string _clientId;
        private readonly string _deploymentProfile;

        public AutopilotTelemetryCollector(Microsoft.Extensions.Configuration.IConfiguration configuration)
        {
            _deploymentProfile = configuration.GetValue<string>("TelemetrySettings:DeploymentProfile", "Standard")!;
            _clientId = GenerateClientId();
}

        public string GetClientId() => _clientId;

        public TelemetryData CollectTelemetry()
{
            var espStatus = GetEspStatus();
      var phaseInfo = GetCurrentPhase();

    return new TelemetryData
            {
    ClientId = _clientId,
      DeviceName = Environment.MachineName,
      DeploymentProfile = _deploymentProfile,
       PhaseName = phaseInfo.Phase,
     EventType = "progress",
        EventTimestamp = DateTime.UtcNow,
   ProgressPercentage = phaseInfo.Progress,
             Status = phaseInfo.Status,
     ErrorMessage = phaseInfo.Error,
         Metadata = new Dictionary<string, object>
       {
         { "esp_active", espStatus.IsActive },
              { "enrollment_state", espStatus.EnrollmentState ?? 0 },
     { "last_error", espStatus.LastError ?? 0 },
   { "os_version", Environment.OSVersion.Version.ToString() }
        }
            };
        }

     private string GenerateClientId()
        {
      var computerName = Environment.MachineName;
            var serialNumber = GetBiosSerialNumber();
            return $"{computerName}-{serialNumber}";
        }

        private string GetBiosSerialNumber()
        {
  try
   {
            using (var searcher = new ManagementObjectSearcher("SELECT SerialNumber FROM Win32_BIOS"))
      {
              foreach (ManagementObject obj in searcher.Get())
               {
      return obj["SerialNumber"]?.ToString() ?? "UNKNOWN";
      }
 }
        }
      catch
          {
    return "UNKNOWN";
   }

        return "UNKNOWN";
      }

        private EspStatus GetEspStatus()
  {
 try
       {
       const string espRegPath = @"SOFTWARE\Microsoft\Enrollments";
         using (var key = Registry.LocalMachine.OpenSubKey(espRegPath))
   {
         if (key != null)
    {
    foreach (var subKeyName in key.GetSubKeyNames())
          {
               using (var subKey = key.OpenSubKey(subKeyName))
          {
       if (subKey != null)
     {
     var enrollmentState = subKey.GetValue("EnrollmentState");
    var lastError = subKey.GetValue("LastError");

         if (enrollmentState != null)
                  {
       return new EspStatus
{
      IsActive = true,
  EnrollmentState = Convert.ToInt32(enrollmentState),
           LastError = lastError != null ? Convert.ToInt32(lastError) : null
   };
  }
      }
          }
      }
  }
         }
            }
   catch (Exception ex)
            {
return new EspStatus
           {
          IsActive = false,
    Error = ex.Message
   };
            }

     return new EspStatus { IsActive = false };
   }

        private PhaseInfo GetCurrentPhase()
        {
            try
            {
      var phase = "Device Preparation";
       var progress = 0;

    // Check if device setup is complete
                if (RegistryKeyExists(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"))
                {
             phase = "Device Setup";
           progress = 20;
    }

            // Check if user profile is being set up
   if (CountProfilesGreaterThan(2))
           {
   phase = "Account Setup";
     progress = 40;
         }

        // Check if apps are being installed
        if (RegistryKeyExists(@"SOFTWARE\Microsoft\IntuneManagementExtension\Apps"))
          {
     phase = "Apps Installation";
       progress = 60;
              }

      // Check if policies are applied
           if (RegistryKeyExists(@"SOFTWARE\Microsoft\PolicyManager\current"))
         {
    phase = "Policies Application";
                progress = 80;
    }

   // Check if ESP is complete
  if (RegistryKeyExists(@"SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache"))
{
   phase = "Completion";
         progress = 100;
           }

      return new PhaseInfo
      {
          Phase = phase,
      Progress = progress,
     Status = progress == 100 ? "completed" : "in_progress"
                };
      }
    catch (Exception ex)
 {
                return new PhaseInfo
 {
           Phase = "Unknown",
          Progress = 0,
     Status = "error",
      Error = ex.Message
         };
            }
        }

        private bool RegistryKeyExists(string subKey)
        {
            try
            {
    using (var key = Registry.LocalMachine.OpenSubKey(subKey))
    {
           return key != null;
       }
    }
        catch
            {
     return false;
    }
        }

    private bool CountProfilesGreaterThan(int count)
  {
            try
    {
        const string profilePath = @"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList";
    using (var key = Registry.LocalMachine.OpenSubKey(profilePath))
          {
             return key != null && key.GetSubKeyNames().Length > count;
 }
          }
        catch
            {
                return false;
    }
        }
    }
}
