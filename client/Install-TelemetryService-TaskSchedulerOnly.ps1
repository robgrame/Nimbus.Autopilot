<#
.SYNOPSIS
    Install Nimbus Autopilot Telemetry usando SOLO Task Scheduler
    
.DESCRIPTION
    Questa è l'opzione PIÙ SEMPLICE - usa solo Task Scheduler di Windows.
    Nessun servizio, nessun tool esterno. Solo componenti nativi Windows.
    
.PARAMETER ApiEndpoint
    The base URL of the Nimbus API
    
.PARAMETER ApiKey
    API key for authentication

.PARAMETER DeploymentProfile
    Name of the Autopilot deployment profile
    
.PARAMETER IntervalSeconds
    Interval between telemetry submissions in seconds
    
.PARAMETER TaskName
    Name of the scheduled task (default: NimbusAutopilotTelemetry)
    
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\Nimbus\Autopilot)
    
.EXAMPLE
    .\Install-TelemetryService-TaskSchedulerOnly.ps1 -ApiEndpoint "https://api.example.com" -ApiKey "your_key"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ApiEndpoint,
    
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentProfile = "Standard",
    
    [Parameter(Mandatory=$false)]
    [int]$IntervalSeconds = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "NimbusAutopilotTelemetry",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\Nimbus\Autopilot"
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=== Nimbus Autopilot Telemetry Installation (Task Scheduler Only) ===" -ForegroundColor Cyan
Write-Host ""

# Create installation directory
Write-Host "[1/4] Creating installation directory..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy telemetry scripts
Write-Host "[2/4] Copying telemetry scripts..." -ForegroundColor Yellow
$scriptFiles = @(
    "Send-AutopilotTelemetry.ps1",
    "Send-AutopilotTelemetry-Service.ps1"
)

foreach ($file in $scriptFiles) {
    $sourcePath = Join-Path $PSScriptRoot $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $InstallPath -Force
     Write-Host "  Copied: $file" -ForegroundColor Green
    } else {
   Write-Warning "  File not found: $file"
    }
}

# Create configuration file
Write-Host "[3/4] Creating configuration file..." -ForegroundColor Yellow
$configPath = Join-Path $InstallPath "config.json"
$config = @{
    ApiEndpoint = $ApiEndpoint
    ApiKey = $ApiKey
    DeploymentProfile = $DeploymentProfile
    IntervalSeconds = $IntervalSeconds
} | ConvertTo-Json

Set-Content -Path $configPath -Value $config -Force
Write-Host "  Configuration saved to: $configPath" -ForegroundColor Green

# Create Task Scheduler task
Write-Host "[4/4] Creating Task Scheduler task..." -ForegroundColor Yellow

$servicePsScript = Join-Path $InstallPath "Send-AutopilotTelemetry-Service.ps1"
$taskDescription = "Nimbus Autopilot Telemetry - Monitors and reports Autopilot deployment progress"

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "  Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create task action
$taskAction = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$servicePsScript`" -ConfigPath `"$configPath`""

# Create multiple triggers for reliability
$triggers = @()

# Trigger 1: At startup
$triggers += New-ScheduledTaskTrigger -AtStartup

# Trigger 2: At logon of any user (catches cases where startup might fail)
$triggers += New-ScheduledTaskTrigger -AtLogOn

# Trigger 3: Repeating every 5 minutes (ensures it's always running)
$repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
$triggers += $repeatTrigger

# Create task settings with aggressive restart policy
$taskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
    -ExecutionTimeLimit 0 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 999 `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew  # Don't start new instance if already running

# Create task principal (run as SYSTEM)
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Description $taskDescription `
    -Action $taskAction `
    -Trigger $triggers `
    -Settings $taskSettings `
    -Principal $taskPrincipal `
    -Force | Out-Null

Write-Host "  Task created successfully" -ForegroundColor Green

# Start the task immediately
Write-Host "  Starting task..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 3

# Verify task is running
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue

if ($task -and $taskInfo.LastTaskResult -eq 0) {
    Write-Host "  Task started successfully" -ForegroundColor Green
} else {
    Write-Warning "  Task may not be running. Last result: $($taskInfo.LastTaskResult)"
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Task Name:          $TaskName" -ForegroundColor Cyan
Write-Host "Installation Path:  $InstallPath" -ForegroundColor Cyan
Write-Host "Task Status:    $($task.State)" -ForegroundColor Cyan
Write-Host "Last Run:           $($taskInfo.LastRunTime)" -ForegroundColor Cyan
Write-Host "Next Run:           $($taskInfo.NextRunTime)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Logs Location:      $env:ProgramData\Nimbus\Logs\" -ForegroundColor Yellow
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  View Task:        Get-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host "  Start Task:       Start-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host "  Stop Task:        Stop-ScheduledTask -TaskName $TaskName" -ForegroundColor Gray
Write-Host "  View Logs:  Get-Content '$env:ProgramData\Nimbus\Logs\telemetry-*.log' -Tail 50 -Wait" -ForegroundColor Gray
Write-Host ""
Write-Host "VANTAGGI: Usa SOLO componenti nativi Windows - nessun tool esterno!" -ForegroundColor Green
Write-Host "NOTA: Il task viene eseguito ogni 5 minuti per garantire che sia sempre attivo" -ForegroundColor Cyan
Write-Host ""
