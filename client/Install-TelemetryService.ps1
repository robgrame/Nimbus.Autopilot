<#
.SYNOPSIS
    Install Nimbus Autopilot Telemetry as a Windows Service
    
.DESCRIPTION
    This script installs the telemetry client as a Windows Service using NSSM,
    with Task Scheduler as a backup mechanism for resilience.
    
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
    .\Install-TelemetryService.ps1 -ApiEndpoint "https://api.example.com" -ApiKey "your_key"
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

Write-Host "=== Nimbus Autopilot Telemetry Service Installation ===" -ForegroundColor Cyan
Write-Host ""

# Create installation directory
Write-Host "[1/7] Creating installation directory..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy telemetry scripts
Write-Host "[2/7] Copying telemetry scripts..." -ForegroundColor Yellow
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
Write-Host "[3/7] Creating configuration file..." -ForegroundColor Yellow
$configPath = Join-Path $InstallPath "config.json"
$config = @{
    ApiEndpoint = $ApiEndpoint
  ApiKey = $ApiKey
    DeploymentProfile = $DeploymentProfile
    IntervalSeconds = $IntervalSeconds
} | ConvertTo-Json

Set-Content -Path $configPath -Value $config -Force
Write-Host "  Configuration saved to: $configPath" -ForegroundColor Green

# Download and install NSSM if not present
Write-Host "[4/7] Checking NSSM (Non-Sucking Service Manager)..." -ForegroundColor Yellow
$nssmPath = Join-Path $InstallPath "nssm.exe"

if (-not (Test-Path $nssmPath)) {
    Write-Host "  Downloading NSSM..." -ForegroundColor Yellow
    $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
    $nssmZip = Join-Path $env:TEMP "nssm.zip"
    $nssmExtract = Join-Path $env:TEMP "nssm"
    
    try {
        Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
  Expand-Archive -Path $nssmZip -DestinationPath $nssmExtract -Force
 
        # Determine architecture
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
   $nssmExe = Get-ChildItem -Path $nssmExtract -Recurse -Filter "nssm.exe" | Where-Object { $_.FullName -like "*\$arch\*" } | Select-Object -First 1
        
        if ($nssmExe) {
            Copy-Item -Path $nssmExe.FullName -Destination $nssmPath -Force
    Write-Host "  NSSM installed successfully" -ForegroundColor Green
        } else {
            throw "NSSM executable not found in download"
        }
    } catch {
        Write-Error "Failed to download/install NSSM: $_"
        Write-Host "  Please download NSSM manually from https://nssm.cc/ and place nssm.exe in $InstallPath"
        exit 1
    } finally {
    # Cleanup
     if (Test-Path $nssmZip) { Remove-Item $nssmZip -Force }
        if (Test-Path $nssmExtract) { Remove-Item $nssmExtract -Recurse -Force }
    }
} else {
 Write-Host "  NSSM already installed" -ForegroundColor Green
}

# Install Windows Service using NSSM
Write-Host "[5/7] Installing Windows Service..." -ForegroundColor Yellow

# Remove existing service if present
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Stopping and removing existing service..." -ForegroundColor Yellow
    & $nssmPath stop $ServiceName
    Start-Sleep -Seconds 2
    & $nssmPath remove $ServiceName confirm
 Start-Sleep -Seconds 2
}

# Install new service
$servicePsScript = Join-Path $InstallPath "Send-AutopilotTelemetry-Service.ps1"
$arguments = @(
    "-ExecutionPolicy", "Bypass",
  "-NoProfile",
    "-File", "`"$servicePsScript`"",
  "-ConfigPath", "`"$configPath`""
)

& $nssmPath install $ServiceName "PowerShell.exe" $arguments

if ($LASTEXITCODE -eq 0) {
 Write-Host "  Service installed successfully" -ForegroundColor Green
} else {
    Write-Error "Failed to install service (Exit code: $LASTEXITCODE)"
    exit 1
}

# Configure service
& $nssmPath set $ServiceName Description "Nimbus Autopilot Telemetry Service - Monitors and reports Autopilot deployment progress"
& $nssmPath set $ServiceName DisplayName "Nimbus Autopilot Telemetry"
& $nssmPath set $ServiceName Start SERVICE_AUTO_START
& $nssmPath set $ServiceName AppStdout "$env:ProgramData\Nimbus\Logs\service-stdout.log"
& $nssmPath set $ServiceName AppStderr "$env:ProgramData\Nimbus\Logs\service-stderr.log"
& $nssmPath set $ServiceName AppRotateFiles 1
& $nssmPath set $ServiceName AppRotateBytes 1048576  # 1MB
& $nssmPath set $ServiceName AppThrottle 1500  # Restart throttle in milliseconds

Write-Host "  Service configured" -ForegroundColor Green

# Create Task Scheduler backup
Write-Host "[6/7] Creating Task Scheduler backup..." -ForegroundColor Yellow

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
& $nssmPath start $ServiceName
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
Write-Host "Service Name:     $ServiceName" -ForegroundColor Cyan
Write-Host "Installation Path:  $InstallPath" -ForegroundColor Cyan
Write-Host "Service Status:     $($service.Status)" -ForegroundColor Cyan
Write-Host "Backup Task:        $taskName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Logs Location:      $env:ProgramData\Nimbus\Logs\" -ForegroundColor Yellow
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  View Service:     Get-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  Stop Service:     Stop-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  Start Service:    Start-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  View Logs:        Get-Content '$env:ProgramData\Nimbus\Logs\telemetry-*.log' -Tail 50 -Wait" -ForegroundColor Gray
Write-Host ""
