using Newtonsoft.Json;
using System;
using System.IO;

namespace Nimbus.Autopilot.TelemetryService
{
    public interface IStateManager
 {
 DateTime GetDeploymentStartTime();
        void SaveDeploymentStartTime(DateTime startTime);
     string? GetLastPhase();
        void SaveLastPhase(string phase);
    int GetLastProgress();
        void SaveLastProgress(int progress);
  }

    public class StateManager : IStateManager
{
 private readonly string _stateFilePath;
 private StateData _state;

 public StateManager()
  {
      var dataPath = Path.Combine(
   Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
"Nimbus");
   
       if (!Directory.Exists(dataPath))
    {
       Directory.CreateDirectory(dataPath);
    }

          _stateFilePath = Path.Combine(dataPath, "telemetry-state.json");
       _state = LoadState();
   }

 public DateTime GetDeploymentStartTime()
 {
  return _state.DeploymentStartTime;
  }

        public void SaveDeploymentStartTime(DateTime startTime)
  {
    _state.DeploymentStartTime = startTime;
     SaveState();
  }

     public string? GetLastPhase()
{
       return _state.LastPhase;
        }

    public void SaveLastPhase(string phase)
  {
   _state.LastPhase = phase;
  SaveState();
        }

        public int GetLastProgress()
   {
     return _state.LastProgress;
 }

        public void SaveLastProgress(int progress)
{
   _state.LastProgress = progress;
       SaveState();
     }

      private StateData LoadState()
  {
    try
   {
   if (File.Exists(_stateFilePath))
       {
        var json = File.ReadAllText(_stateFilePath);
     return JsonConvert.DeserializeObject<StateData>(json) ?? new StateData();
   }
  }
   catch
     {
         // If state file is corrupted, start fresh
      }

       return new StateData();
        }

  private void SaveState()
  {
   try
  {
        var json = JsonConvert.SerializeObject(_state, Formatting.Indented);
   File.WriteAllText(_stateFilePath, json);
 }
       catch
    {
         // Log error but don't fail the service
   }
        }

  private class StateData
    {
 public DateTime DeploymentStartTime { get; set; } = DateTime.MinValue;
    public string? LastPhase { get; set; }
    public int LastProgress { get; set; } = -1;
     public DateTime? LastSuccessfulSend { get; set; }
   public int? LastEventId { get; set; }
 }
    }
}
