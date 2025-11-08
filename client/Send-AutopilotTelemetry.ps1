<#
.SYNOPSIS
    Nimbus Autopilot Telemetry Client
    
.DESCRIPTION
    PowerShell script to monitor Windows Autopilot Enrollment Status Page (ESP)
    progress and send telemetry data to the Nimbus API backend.
    
.PARAMETER ApiEndpoint
    The base URL of the Nimbus API (default: http://localhost:5000)
    
.PARAMETER ApiKey
    API key for authentication
    
.PARAMETER ClientId
    Unique identifier for this client device (default: computer name + serial)
    
.PARAMETER DeploymentProfile
    Name of the Autopilot deployment profile
    
.PARAMETER IntervalSeconds
    Interval between telemetry submissions in seconds (default: 30)
    
.EXAMPLE
    .\Send-AutopilotTelemetry.ps1 -ApiEndpoint "https://api.example.com" -ApiKey "your_key"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ApiEndpoint = "http://localhost:5000",
    
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentProfile = "Standard",
    
    [Parameter(Mandatory=$false)]
    [int]$IntervalSeconds = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxRetries = 3
)

# Set up logging
$LogPath = "$env:ProgramData\Nimbus\Logs"
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}
$LogFile = Join-Path $LogPath "telemetry-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    Write-Verbose $LogMessage
}

# Get or generate Client ID
if (-not $ClientId) {
    $ComputerName = $env:COMPUTERNAME
    $SerialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    $ClientId = "$ComputerName-$SerialNumber"
}

Write-Log "Starting Nimbus Autopilot Telemetry Client"
Write-Log "Client ID: $ClientId"
Write-Log "API Endpoint: $ApiEndpoint"

# Function to get ESP status
function Get-ESPStatus {
    try {
        # Check if ESP is running by looking for Enrollment Status Page registry keys
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
        # Check various indicators to determine current phase
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
            if ($profiles.Count -gt 2) {  # More than system profiles
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

# Function to send telemetry to API
function Send-Telemetry {
    param(
        [hashtable]$Data,
        [int]$RetryCount = 0
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
                                     -TimeoutSec 10
        
        Write-Log "Telemetry sent successfully. Event ID: $($response.event_id)"
        return $true
    }
    catch {
        Write-Log "Error sending telemetry (Attempt $($RetryCount + 1)/$MaxRetries): $_" "ERROR"
        
        if ($RetryCount -lt $MaxRetries) {
            Start-Sleep -Seconds ([Math]::Pow(2, $RetryCount))  # Exponential backoff
            return Send-Telemetry -Data $Data -RetryCount ($RetryCount + 1)
        }
        
        return $false
    }
}

# Main monitoring loop
Write-Log "Starting telemetry monitoring loop"
$startTime = Get-Date
$lastPhase = $null
$lastProgress = -1

while ($true) {
    try {
        # Get current ESP status
        $espStatus = Get-ESPStatus
        
        # Get current deployment phase and progress
        $phaseInfo = Get-CurrentPhase
        
        # Calculate duration
        $duration = ((Get-Date) - $startTime).TotalSeconds
        
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
            duration_seconds = [int]$duration
            error_message = $phaseInfo.Error
            metadata = @{
                esp_active = $espStatus.IsActive
                enrollment_state = $espStatus.EnrollmentState
                last_error = $espStatus.LastError
                os_version = [System.Environment]::OSVersion.Version.ToString()
            }
        }
        
        # Only send telemetry if phase or progress changed significantly
        $shouldSend = ($phaseInfo.Phase -ne $lastPhase) -or 
                      ([Math]::Abs($phaseInfo.Progress - $lastProgress) -ge 5) -or
                      ($phaseInfo.Status -eq "completed") -or
                      ($phaseInfo.Status -eq "error")
        
        if ($shouldSend) {
            $success = Send-Telemetry -Data $telemetryData
            
            if ($success) {
                $lastPhase = $phaseInfo.Phase
                $lastProgress = $phaseInfo.Progress
            }
        }
        else {
            Write-Log "No significant change, skipping telemetry submission"
        }
        
        # Exit if deployment is complete
        if ($phaseInfo.Status -eq "completed") {
            Write-Log "Deployment completed successfully"
            
            # Send final completion event
            $telemetryData.event_type = "completion"
            Send-Telemetry -Data $telemetryData
            
            break
        }
        
        # Wait before next check
        Start-Sleep -Seconds $IntervalSeconds
    }
    catch {
        Write-Log "Error in main loop: $_" "ERROR"
        Start-Sleep -Seconds $IntervalSeconds
    }
}

Write-Log "Nimbus Autopilot Telemetry Client finished"
