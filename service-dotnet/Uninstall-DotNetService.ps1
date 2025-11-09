<#
.SYNOPSIS
    Uninstall Nimbus Autopilot Telemetry Windows Service (.NET)
    
.DESCRIPTION
    Rimuove il servizio Windows .NET e tutti i file associati.
    
.PARAMETER ServiceName
    Name of the Windows Service (default: NimbusAutopilotTelemetry)
    
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\Nimbus\AutopilotService)
    
.PARAMETER KeepState
    Keep state file after uninstallation
    
.EXAMPLE
    .\Uninstall-DotNetService.ps1
    
.EXAMPLE
    .\Uninstall-DotNetService.ps1 -KeepState
#>

[CmdletBinding()]
param(
 [Parameter(Mandatory=$false)]
    [string]$ServiceName = "NimbusAutopilotTelemetry",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\Nimbus\AutopilotService",
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepState
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=== Nimbus Autopilot Telemetry Service Uninstallation (.NET) ===" -ForegroundColor Cyan
Write-Host ""

# Stop and remove Windows Service
Write-Host "[1/3] Removing Windows Service..." -ForegroundColor Yellow
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  Stopping service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
 Start-Sleep -Seconds 2
    
    Write-Host "  Removing service..." -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
  Start-Sleep -Seconds 2
    
    Write-Host "  Service removed successfully" -ForegroundColor Green
} else {
    Write-Host "  Service not found (already removed)" -ForegroundColor Gray
}

# Remove Event Log source
Write-Host "[2/3] Removing Event Log source..." -ForegroundColor Yellow
try {
    if ([System.Diagnostics.EventLog]::SourceExists("Nimbus Autopilot Telemetry")) {
        [System.Diagnostics.EventLog]::DeleteEventSource("Nimbus Autopilot Telemetry")
        Write-Host "  Event Log source removed" -ForegroundColor Green
    } else {
   Write-Host "  Event Log source not found" -ForegroundColor Gray
    }
} catch {
    Write-Warning "  Could not remove Event Log source: $_"
}

# Remove installation files
Write-Host "[3/3] Removing installation files..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
  Remove-Item -Path $InstallPath -Recurse -Force
    Write-Host "  Installation directory removed" -ForegroundColor Green
} else {
    Write-Host "  Installation directory not found" -ForegroundColor Gray
}

# Clean up state file
if (-not $KeepState) {
    $statePath = "$env:ProgramData\Nimbus"
 if (Test-Path $statePath) {
        $stateFile = Join-Path $statePath "telemetry-state.json"
        if (Test-Path $stateFile) {
         Remove-Item $stateFile -Force
  Write-Host "  State file removed" -ForegroundColor Green
        }
        
        # Remove directory if empty
   $remainingFiles = Get-ChildItem -Path $statePath -Recurse
    if ($remainingFiles.Count -eq 0) {
            Remove-Item -Path $statePath -Force
        }
    }
}

Write-Host ""
Write-Host "=== Uninstallation Complete ===" -ForegroundColor Green
Write-Host ""

if ($KeepState) {
    Write-Host "State file retained at: $env:ProgramData\Nimbus\telemetry-state.json" -ForegroundColor Yellow
}

Write-Host ""
