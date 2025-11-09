<#
.SYNOPSIS
    Install Nimbus Autopilot Telemetry Windows Service (.NET)
    
.DESCRIPTION
 Installa il servizio Windows .NET nativo per il monitoraggio continuo di Autopilot.
    Non richiede tool esterni - usa solo componenti nativi Windows.
    
.PARAMETER ApiEndpoint
    The base URL of the Nimbus API
    
.PARAMETER ApiKey
    API key for authentication

.PARAMETER DeploymentProfile
    Name of the Autopilot deployment profile
    
.PARAMETER ServiceName
    Name of the Windows Service (default: NimbusAutopilotTelemetry)
    
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\Nimbus\AutopilotService)
    
.PARAMETER ServiceExecutable
    Path to the compiled service executable
    
.EXAMPLE
    .\Install-DotNetService.ps1 -ApiEndpoint "https://api.example.com" -ApiKey "your_key" -ServiceExecutable "C:\Build\Nimbus.Autopilot.TelemetryService.exe"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
 [string]$ApiEndpoint,
    
    [Parameter(Mandatory=$true)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$true)]
    [string]$ServiceExecutable,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentProfile = "Standard",
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "NimbusAutopilotTelemetry",
 
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\Nimbus\AutopilotService"
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=== Nimbus Autopilot Telemetry Service Installation (.NET Native) ===" -ForegroundColor Cyan
Write-Host ""

# Verify service executable exists
if (-not (Test-Path $ServiceExecutable)) {
    Write-Error "Service executable not found: $ServiceExecutable"
    Write-Host "Please build the service project first:" -ForegroundColor Yellow
    Write-Host "  cd service-dotnet\Nimbus.Autopilot.TelemetryService" -ForegroundColor Gray
    Write-Host "  dotnet publish -c Release -r win-x64 --self-contained false" -ForegroundColor Gray
    exit 1
}

# Create installation directory
Write-Host "[1/5] Creating installation directory..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy service files
Write-Host "[2/5] Copying service files..." -ForegroundColor Yellow
$sourceDir = Split-Path $ServiceExecutable -Parent

# Copy all files from build output
Copy-Item -Path "$sourceDir\*" -Destination $InstallPath -Recurse -Force
Write-Host "  Service files copied to: $InstallPath" -ForegroundColor Green

# Update configuration file
Write-Host "[3/5] Updating configuration..." -ForegroundColor Yellow
$configPath = Join-Path $InstallPath "appsettings.json"

if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $config.TelemetrySettings.ApiEndpoint = $ApiEndpoint
    $config.TelemetrySettings.ApiKey = $ApiKey
    $config.TelemetrySettings.DeploymentProfile = $DeploymentProfile
    
 $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
    Write-Host "  Configuration updated: $configPath" -ForegroundColor Green
} else {
 Write-Warning "  Configuration file not found, creating new one..."
    $config = @{
      Logging = @{
            LogLevel = @{
  Default = "Information"
     Microsoft = "Warning"
      }
        EventLog = @{
    SourceName = "Nimbus Autopilot Telemetry"
         LogName = "Application"
 }
        }
        TelemetrySettings = @{
            ApiEndpoint = $ApiEndpoint
          ApiKey = $ApiKey
    DeploymentProfile = $DeploymentProfile
            IntervalSeconds = 30
            HeartbeatIntervalSeconds = 300
  MaxRetries = 3
        }
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
}

# Install Windows Service
Write-Host "[4/5] Installing Windows Service..." -ForegroundColor Yellow

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
$serviceExePath = Join-Path $InstallPath (Split-Path $ServiceExecutable -Leaf)
$result = sc.exe create $ServiceName binPath= "`"$serviceExePath`"" start= auto DisplayName= "Nimbus Autopilot Telemetry"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Service created successfully" -ForegroundColor Green
    
    # Set description
    sc.exe description $ServiceName "Monitors and reports Autopilot deployment progress to Nimbus API (.NET Service)" | Out-Null
    
    # Configure failure actions (restart on failure)
    sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
  
    Write-Host "  Service configured with auto-restart on failure" -ForegroundColor Green
} else {
    Write-Error "Failed to create service (Exit code: $LASTEXITCODE)"
    exit 1
}

# Create Event Log source if it doesn't exist
Write-Host "[5/5] Configuring Event Log..." -ForegroundColor Yellow
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists("Nimbus Autopilot Telemetry")) {
   [System.Diagnostics.EventLog]::CreateEventSource("Nimbus Autopilot Telemetry", "Application")
     Write-Host "  Event Log source created" -ForegroundColor Green
    } else {
   Write-Host "  Event Log source already exists" -ForegroundColor Green
    }
} catch {
    Write-Warning "  Could not create Event Log source: $_"
}

# Start the service
Write-Host ""
Write-Host "Starting service..." -ForegroundColor Yellow
Start-Service -Name $ServiceName

Start-Sleep -Seconds 3

# Verify service is running
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "  Service started successfully" -ForegroundColor Green
} else {
  Write-Warning "  Service may not be running. Status: $($service.Status)"
    Write-Host "  Check Event Viewer (Application log) for details" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Service Name:       $ServiceName" -ForegroundColor Cyan
Write-Host "Installation Path:  $InstallPath" -ForegroundColor Cyan
Write-Host "Service Status:     $($service.Status)" -ForegroundColor Cyan
Write-Host "Service Type:       .NET Native Windows Service" -ForegroundColor Cyan
Write-Host ""
Write-Host "State File:  $env:ProgramData\Nimbus\telemetry-state.json" -ForegroundColor Yellow
Write-Host "Event Log:          Application > Nimbus Autopilot Telemetry" -ForegroundColor Yellow
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  View Service:     Get-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  Stop Service:     Stop-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  Start Service:    Start-Service -Name $ServiceName" -ForegroundColor Gray
Write-Host "  View Event Log:   Get-EventLog -LogName Application -Source 'Nimbus Autopilot Telemetry' -Newest 50" -ForegroundColor Gray
Write-Host "  View State:       Get-Content '$env:ProgramData\Nimbus\telemetry-state.json'" -ForegroundColor Gray
Write-Host ""
Write-Host "VANTAGGI:" -ForegroundColor Green
Write-Host "  ? Windows Service nativo .NET - nessun tool esterno" -ForegroundColor Green
Write-Host "  ? Event Log integrato per logging" -ForegroundColor Green
Write-Host "  ? Compatibile con .NET Framework 4.8 (già installato su Windows 10/11)" -ForegroundColor Green
Write-Host "  ? Gestione standard con Services.msc" -ForegroundColor Green
Write-Host ""
