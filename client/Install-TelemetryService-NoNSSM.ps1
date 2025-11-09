<#
.SYNOPSIS
    Install Nimbus Autopilot Telemetry as a Windows Service (senza NSSM)
    
.DESCRIPTION
    Questo script installa il servizio usando sc.exe nativo di Windows.
    Non richiede download di tool esterni.
    
.PARAMETER ApiEndpoint
    The base URL of the Nimbus API
    
.PARAMETER ApiKey
    API key for authentication

.PARAMETER DeploymentProfile
    Name of the Autopilot deployment profile
    
.PARAMETER IntervalSeconds
    Interval between telemetry submissions in seconds
    
.PARAMETER ServiceName
    Name of the Windows Service (default: NimbusAutopilotTelemetry)
    
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\Nimbus\Autopilot)
    
.EXAMPLE
    .\Install-TelemetryService-NoNSSM.ps1 -ApiEndpoint "https://api.example.com" -ApiKey "your_key"
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
    [string]$ServiceName = "NimbusAutopilotTelemetry",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\Nimbus\Autopilot"
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=== Nimbus Autopilot Telemetry Service Installation (sc.exe) ===" -ForegroundColor Cyan
Write-Host ""

# Create installation directory
Write-Host "[1/5] Creating installation directory..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
 New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy telemetry scripts
Write-Host "[2/5] Copying telemetry scripts..." -ForegroundColor Yellow
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
Write-Host "[3/5] Creating configuration file..." -ForegroundColor Yellow
$configPath = Join-Path $InstallPath "config.json"
$config = @{
  ApiEndpoint = $ApiEndpoint
    ApiKey = $ApiKey
    DeploymentProfile = $DeploymentProfile
    IntervalSeconds = $IntervalSeconds
} | ConvertTo-Json

Set-Content -Path $configPath -Value $config -Force
Write-Host "  Configuration saved to: $configPath" -ForegroundColor Green

# Create wrapper batch file for the service
Write-Host "[4/5] Creating service wrapper..." -ForegroundColor Yellow
$servicePsScript = Join-Path $InstallPath "Send-AutopilotTelemetry-Service.ps1"
$wrapperBat = Join-Path $InstallPath "ServiceWrapper.bat"

$batContent = @"
@echo off
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File "$servicePsScript" -ConfigPath "$configPath"
"@

Set-Content -Path $wrapperBat -Value $batContent -Force
Write-Host "  Service wrapper created: $wrapperBat" -ForegroundColor Green

# Install Windows Service using sc.exe
Write-Host "[5/5] Installing Windows Service..." -ForegroundColor Yellow

# Remove existing service if present
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Stopping and removing existing service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# Create service using sc.exe
$result = sc.exe create $ServiceName binPath= "`"$wrapperBat`"" start= auto DisplayName= "Nimbus Autopilot Telemetry"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Service created successfully" -ForegroundColor Green
    
    # Set description
    sc.exe description $ServiceName "Monitors and reports Autopilot deployment progress to Nimbus API" | Out-Null
    
    # Configure failure actions (restart on failure)
    sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
    
    Write-Host "  Service configured with auto-restart on failure" -ForegroundColor Green
} else {
    Write-Error "Failed to create service (Exit code: $LASTEXITCODE)"
    exit 1
}

# Create Task Scheduler backup
Write-Host "[6/6] Creating Task Scheduler backup..." -ForegroundColor Yellow

$taskName = "$ServiceName-Backup"
$taskDescription = "Backup task for Nimbus Autopilot Telemetry Service - runs if service fails"

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create task action
$taskAction = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$servicePsScript`" -ConfigPath `"$configPath`""

# Create task trigger (at startup + every 15 minutes)
$taskTriggerStartup = New-ScheduledTaskTrigger -AtStartup
$taskTriggerRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::MaxValue)

# Create task settings
$taskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit 0 `
-RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 999 `
    -RunOnlyIfNetworkAvailable

# Create task principal (run as SYSTEM)
$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register task
Register-ScheduledTask `
    -TaskName $taskName `
    -Description $taskDescription `
    -Action $taskAction `
    -Trigger @($taskTriggerStartup, $taskTriggerRepeat) `
    -Settings $taskSettings `
    -Principal $taskPrincipal `
    -Force | Out-Null

Write-Host "  Task Scheduler backup created: $taskName" -ForegroundColor Green

# Start the service
Write-Host "[7/7] Starting service..." -ForegroundColor Yellow
Start-Service -Name $ServiceName

Start-Sleep -Seconds 3

# Verify service is running
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "  Service started successfully" -ForegroundColor Green
} else {
    Write-Warning "  Service may not be running. Please check Event Viewer for details."
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Service Name:       $ServiceName" -ForegroundColor Cyan
Write-Host "Installation Path:  $InstallPath" -ForegroundColor Cyan
Write-Host "Service Status:     $($service.Status)" -ForegroundColor Cyan
Write-Host "Backup Task:        $taskName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Logs Location:      $env:ProgramData\Nimbus\Logs\" -ForegroundColor Yellow
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  View Service:     Get-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "Stop Service:     Stop-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  Start Service:    Start-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  View Logs:Get-Content '$env:ProgramData\Nimbus\Logs\telemetry-*.log' -Tail 50 -Wait" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTA: Questo servizio usa sc.exe nativo di Windows (nessun tool esterno richiesto)" -ForegroundColor Cyan
Write-Host ""
