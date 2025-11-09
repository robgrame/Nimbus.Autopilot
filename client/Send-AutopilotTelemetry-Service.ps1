<#
.SYNOPSIS
    Nimbus Autopilot Telemetry Service - Continuous Runner
    
.DESCRIPTION
    Service-mode version of the telemetry script that runs continuously,
    survives reboots, and maintains state across restarts.
    
.PARAMETER ConfigPath
    Path to the configuration JSON file
    
.EXAMPLE
    .\Send-AutopilotTelemetry-Service.ps1 -ConfigPath "C:\Program Files\Nimbus\Autopilot\config.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
  [string]$ConfigPath
)

# Load configuration
if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$ApiEndpoint = $config.ApiEndpoint
$ApiKey = $config.ApiKey
$DeploymentProfile = $config.DeploymentProfile
$IntervalSeconds = $config.IntervalSeconds

# Set up logging
$LogPath = "$env:ProgramData\Nimbus\Logs"
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}
$LogFile = Join-Path $LogPath "telemetry-$(Get-Date -Format 'yyyyMMdd').log"

# State file for persistence across reboots
$StatePath = "$env:ProgramData\Nimbus"
if (-not (Test-Path $StatePath)) {
    New-Item -ItemType Directory -Path $StatePath -Force | Out-Null
}
$StateFile = Join-Path $StatePath "telemetry-state.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] [SERVICE] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    Write-Verbose $LogMessage
    
 # Also write to console for service stdout
    Write-Host $LogMessage
}

function Save-State {
    param([hashtable]$State)
    try {
        $State | ConvertTo-Json -Depth 10 | Set-Content -Path $StateFile -Force
    } catch {
        Write-Log "Failed to save state: $_" "ERROR"
    }
}

function Load-State {
    try {
        if (Test-Path $StateFile) {
  $stateJson = Get-Content $StateFile -Raw | ConvertFrom-Json
   # Convert PSCustomObject back to hashtable
 $state = @{}
        $stateJson.PSObject.Properties | ForEach-Object {
      $state[$_.Name] = $_.Value
            }
   return $state
        }
    } catch {
    Write-Log "Failed to load state: $_" "ERROR"
    }
    return @{}
}

# Get or generate Client ID
$ComputerName = $env:COMPUTERNAME
$SerialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
$ClientId = "$ComputerName-$SerialNumber"

Write-Log "=== Nimbus Autopilot Telemetry Service Started ==="
Write-Log "Client ID: $ClientId"
Write-Log "API Endpoint: $ApiEndpoint"
Write-Log "Deployment Profile: $DeploymentProfile"
Write-Log "Interval: $IntervalSeconds seconds"

# Load previous state
$state = Load-State
$sessionStartTime = Get-Date

if ($state.ContainsKey("DeploymentStartTime")) {
    Write-Log "Restored previous deployment start time: $($state.DeploymentStartTime)"
    $deploymentStartTime = [DateTime]::Parse($state.DeploymentStartTime)
} else {
    $deploymentStartTime = $sessionStartTime
    $state["DeploymentStartTime"] = $deploymentStartTime.ToString("o")
    Save-State $state
}

# Function to check if service should continue running
function Test-ServiceShouldRun {
    # Check for stop signal file
    $stopSignalFile = Join-Path $StatePath "stop-service.signal"
    if (Test-Path $stopSignalFile) {
      Write-Log "Stop signal detected" "WARN"
        Remove-Item $stopSignalFile -Force
        return $false
    }
    return $true
}

# Function to get ESP status
function Get-ESPStatus {
    try {
        $ESPRegPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
        
      if (Test-Path $ESPRegPath) {
   $enrollments = Get-ChildItem -Path $ESPRegPath
     
            foreach ($enrollment in $enrollments) {
       $enrollmentPath = $enrollment.PSPath
      $status = Get-ItemProperty -Path $enrollmentPath -ErrorAction SilentlyContinue
       
 if ($status) {
         return @{
IsActive = $true
  EnrollmentState = $status.EnrollmentState
       LastError = $status.LastError
          }
       }
    }
        }
      
        return @{
            IsActive = $false
        }
    }
    catch {
    Write-Log "Error getting ESP status: $_" "ERROR"
        return @{
            IsActive = $false
    Error = $_.Exception.Message
 }
  }
}

# Function to determine current deployment phase
function Get-CurrentPhase {
    try {
        $phase = "Device Preparation"
        $progress = 0
        
        # Check if device setup is complete
        $deviceSetupComplete = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"
    if ($deviceSetupComplete) {
        $phase = "Device Setup"
            $progress = 20
        }
        
        # Check if user profile is being set up
        $userProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
        if (Test-Path $userProfilePath) {
     $profiles = Get-ChildItem -Path $userProfilePath
       if ($profiles.Count -gt 2) {
      $phase = "Account Setup"
          $progress = 40
       }
        }
   
        # Check if apps are being installed
   $autopilotApps = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Apps"
        if (Test-Path $autopilotApps) {
     $phase = "Apps Installation"
            $progress = 60
   }
        
        # Check if policies are applied
        $policiesApplied = Test-Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current"
        if ($policiesApplied) {
      $phase = "Policies Application"
 $progress = 80
        }
        
 # Check if ESP is complete
        $espComplete = Test-Path "HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache"
        if ($espComplete) {
         $phase = "Completion"
   $progress = 100
        }
      
        return @{
   Phase = $phase
            Progress = $progress
 Status = if ($progress -eq 100) { "completed" } else { "in_progress" }
        }
    }
    catch {
        Write-Log "Error determining current phase: $_" "ERROR"
        return @{
 Phase = "Unknown"
      Progress = 0
    Status = "error"
   Error = $_.Exception.Message
        }
    }
}

# Function to send telemetry with retry logic
function Send-Telemetry {
    param(
    [hashtable]$Data,
        [int]$RetryCount = 0,
        [int]$MaxRetries = 3
    )
    
 try {
      $headers = @{
         "Content-Type" = "application/json"
 "X-API-Key" = $ApiKey
        }
        
        $body = $Data | ConvertTo-Json -Depth 10
 
        Write-Log "Sending telemetry: $($Data.event_type) - Phase: $($Data.phase_name) - Progress: $($Data.progress_percentage)%"
     
      $response = Invoke-RestMethod -Uri "$ApiEndpoint/api/telemetry" `
         -Method Post `
      -Headers $headers `
         -Body $body `
          -TimeoutSec 30 `
           -ErrorAction Stop
        
     Write-Log "Telemetry sent successfully. Event ID: $($response.event_id)"
        
        # Update state with successful send
        $state["LastSuccessfulSend"] = (Get-Date).ToString("o")
        $state["LastEventId"] = $response.event_id
        Save-State $state
   
      return $true
    }
    catch {
     Write-Log "Error sending telemetry (Attempt $($RetryCount + 1)/$MaxRetries): $_" "ERROR"
     
        if ($RetryCount -lt $MaxRetries) {
$backoffSeconds = [Math]::Pow(2, $RetryCount)
       Write-Log "Retrying in $backoffSeconds seconds..." "WARN"
Start-Sleep -Seconds $backoffSeconds
    return Send-Telemetry -Data $Data -RetryCount ($RetryCount + 1) -MaxRetries $MaxRetries
   }
        
    return $false
    }
}

# Function to send heartbeat
function Send-Heartbeat {
    $heartbeatData = @{
        client_id = $ClientId
        device_name = $env:COMPUTERNAME
        deployment_profile = $DeploymentProfile
        phase_name = "Service Running"
  event_type = "heartbeat"
        event_timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
   progress_percentage = 0
status = "active"
        duration_seconds = [int]((Get-Date) - $deploymentStartTime).TotalSeconds
        metadata = @{
     service_session_start = $sessionStartTime.ToString("o")
            uptime_seconds = [int]((Get-Date) - $sessionStartTime).TotalSeconds
       os_version = [System.Environment]::OSVersion.Version.ToString()
        }
    }
    
    Send-Telemetry -Data $heartbeatData | Out-Null
}

# Main service loop
Write-Log "Starting main service loop"
$lastPhase = $null
$lastProgress = -1
$lastHeartbeat = Get-Date
$heartbeatIntervalSeconds = 300  # 5 minutes

try {
    while (Test-ServiceShouldRun) {
    try {
            # Send periodic heartbeat
   if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatIntervalSeconds) {
   Send-Heartbeat
          $lastHeartbeat = Get-Date
            }
   
            # Get current ESP status
   $espStatus = Get-ESPStatus
            
          # Get current deployment phase and progress
 $phaseInfo = Get-CurrentPhase
       
   # Calculate total duration from initial deployment start
            $totalDuration = ((Get-Date) - $deploymentStartTime).TotalSeconds
            
         # Prepare telemetry data
            $telemetryData = @{
                client_id = $ClientId
        device_name = $env:COMPUTERNAME
      deployment_profile = $DeploymentProfile
      phase_name = $phaseInfo.Phase
  event_type = "progress"
          event_timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        progress_percentage = $phaseInfo.Progress
    status = $phaseInfo.Status
       duration_seconds = [int]$totalDuration
        error_message = $phaseInfo.Error
      metadata = @{
          esp_active = $espStatus.IsActive
     enrollment_state = $espStatus.EnrollmentState
      last_error = $espStatus.LastError
        os_version = [System.Environment]::OSVersion.Version.ToString()
         service_session_uptime = [int]((Get-Date) - $sessionStartTime).TotalSeconds
         deployment_start_time = $deploymentStartTime.ToString("o")
}
          }
  
            # Determine if we should send telemetry
    $shouldSend = ($phaseInfo.Phase -ne $lastPhase) -or 
       ([Math]::Abs($phaseInfo.Progress - $lastProgress) -ge 5) -or
   ($phaseInfo.Status -eq "completed") -or
      ($phaseInfo.Status -eq "error")
    
            if ($shouldSend) {
   $success = Send-Telemetry -Data $telemetryData
          
    if ($success) {
     $lastPhase = $phaseInfo.Phase
         $lastProgress = $phaseInfo.Progress
       
                # Update state
          $state["LastPhase"] = $lastPhase
    $state["LastProgress"] = $lastProgress
        Save-State $state
          }
            } else {
         Write-Log "No significant change, skipping telemetry submission (Phase: $($phaseInfo.Phase), Progress: $($phaseInfo.Progress)%)"
   }
            
        # If deployment is complete, switch to maintenance mode
  if ($phaseInfo.Status -eq "completed") {
     Write-Log "Deployment completed. Entering maintenance mode..."
    
          # Send final completion event
     $telemetryData.event_type = "completion"
    Send-Telemetry -Data $telemetryData
     
       # Continue running but with longer intervals and only heartbeats
 while (Test-ServiceShouldRun) {
     Start-Sleep -Seconds 600  # 10 minutes in maintenance mode
        Send-Heartbeat
   Write-Log "Maintenance mode - heartbeat sent"
       }
          }
  
 # Wait before next check
            Start-Sleep -Seconds $IntervalSeconds
        }
        catch {
       Write-Log "Error in main loop: $_" "ERROR"
            Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
      Start-Sleep -Seconds $IntervalSeconds
        }
    }
}
catch {
    Write-Log "Fatal error in service: $_" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
}
finally {
    Write-Log "=== Nimbus Autopilot Telemetry Service Stopped ==="
}
