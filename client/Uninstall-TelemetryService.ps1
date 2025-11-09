<#
.SYNOPSIS
    Uninstall Nimbus Autopilot Telemetry Service
    
.DESCRIPTION
    Removes the Windows Service and Task Scheduler backup

.PARAMETER ServiceName
    Name of the Windows Service (default: NimbusAutopilotTelemetry)
  
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\Nimbus\Autopilot)
 
.PARAMETER KeepLogs
    Keep log files after uninstallation
    
.PARAMETER KeepConfig
    Keep configuration files after uninstallation
  
.EXAMPLE
    .\Uninstall-TelemetryService.ps1
    
.EXAMPLE
    .\Uninstall-TelemetryService.ps1 -KeepLogs -KeepConfig
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServiceName = "NimbusAutopilotTelemetry",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\Nimbus\Autopilot",
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepLogs,
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepConfig
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "=== Nimbus Autopilot Telemetry Service Uninstallation ===" -ForegroundColor Cyan
Write-Host ""

$nssmPath = Join-Path $InstallPath "nssm.exe"

# Stop and remove Windows Service
Write-Host "[1/4] Removing Windows Service..." -ForegroundColor Yellow
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    if (Test-Path $nssmPath) {
     Write-Host "  Stopping service..." -ForegroundColor Yellow
    & $nssmPath stop $ServiceName 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        
  Write-Host "  Removing service..." -ForegroundColor Yellow
        & $nssmPath remove $ServiceName confirm 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    
        Write-Host "  Service removed successfully" -ForegroundColor Green
    } else {
        Write-Host "  Stopping service with sc.exe..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
        
        sc.exe delete $ServiceName | Out-Null
        Write-Host "  Service removed successfully" -ForegroundColor Green
  }
} else {
    Write-Host "  Service not found (already removed)" -ForegroundColor Gray
}

# Remove Task Scheduler backup
Write-Host "[2/4] Removing Task Scheduler backup..." -ForegroundColor Yellow
$taskName = "$ServiceName-Backup"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  Task removed successfully" -ForegroundColor Green
} else {
    Write-Host "  Task not found (already removed)" -ForegroundColor Gray
}

# Remove installation files
Write-Host "[3/4] Removing installation files..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
    if (-not $KeepConfig) {
        Remove-Item -Path $InstallPath -Recurse -Force
        Write-Host "  Installation directory removed" -ForegroundColor Green
    } else {
   # Remove only script files, keep config
     $filesToRemove = @("Send-AutopilotTelemetry.ps1", "Send-AutopilotTelemetry-Service.ps1", "nssm.exe")
        foreach ($file in $filesToRemove) {
            $filePath = Join-Path $InstallPath $file
        if (Test-Path $filePath) {
          Remove-Item $filePath -Force
  }
   }
        Write-Host "  Script files removed (config kept)" -ForegroundColor Green
    }
} else {
    Write-Host "  Installation directory not found" -ForegroundColor Gray
}

# Clean up logs and state
Write-Host "[4/4] Cleaning up data files..." -ForegroundColor Yellow
if (-not $KeepLogs) {
    $logsPath = "$env:ProgramData\Nimbus\Logs"
    if (Test-Path $logsPath) {
        Remove-Item -Path $logsPath -Recurse -Force
      Write-Host "  Logs removed" -ForegroundColor Green
    }
}

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

Write-Host ""
Write-Host "=== Uninstallation Complete ===" -ForegroundColor Green
Write-Host ""

if ($KeepLogs) {
    Write-Host "Logs retained at: $env:ProgramData\Nimbus\Logs\" -ForegroundColor Yellow
}
if ($KeepConfig) {
    Write-Host "Configuration retained at: $InstallPath\config.json" -ForegroundColor Yellow
}

Write-Host ""
