# Nimbus Autopilot Telemetry Service - Quick Start

## Installation (5 Minutes)

### Step 1: Download Files

Ensure you have these files in the same directory:
- `Install-TelemetryService.ps1`
- `Send-AutopilotTelemetry-Service.ps1`
- `Send-AutopilotTelemetry.ps1`

### Step 2: Run Installation

Open **PowerShell as Administrator** and run:

```powershell
cd C:\path\to\files

.\Install-TelemetryService.ps1 `
    -ApiEndpoint "https://your-api-endpoint.com" `
    -ApiKey "your_api_key_here"
```

**That's it!** The service is now installed and running.

---

## Verify Installation

```powershell
# Check service status
Get-Service -Name NimbusAutopilotTelemetry

# View live logs
Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-$(Get-Date -Format 'yyyyMMdd').log" -Tail 20 -Wait
```

Expected output:
```
Status   : Running
Name     : NimbusAutopilotTelemetry
```

---

## Common Management Commands

```powershell
# Start service
Start-Service -Name NimbusAutopilotTelemetry

# Stop service
Stop-Service -Name NimbusAutopilotTelemetry

# Restart service
Restart-Service -Name NimbusAutopilotTelemetry

# View recent logs
Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-*.log" -Tail 50

# Check service configuration
Get-Content "C:\Program Files\Nimbus\Autopilot\config.json" | ConvertFrom-Json
```

---

## Uninstallation

```powershell
.\Uninstall-TelemetryService.ps1
```

---

## What Was Installed?

? **Windows Service** - Runs automatically on boot  
? **Task Scheduler Backup** - Runs every 15 minutes as failsafe  
? **Configuration File** - `C:\Program Files\Nimbus\Autopilot\config.json`  
? **Log Files** - `C:\ProgramData\Nimbus\Logs\`  
? **State Persistence** - `C:\ProgramData\Nimbus\telemetry-state.json`  

---

## How It Works

```
1. Service starts automatically on device boot
2. Detects current Autopilot deployment phase
3. Sends telemetry to your API every 30 seconds
4. Survives reboots and maintains state
5. Task Scheduler backup ensures reliability
6. Enters maintenance mode after deployment completes
```

---

## Troubleshooting

### Service not starting?

```powershell
# Check error logs
Get-Content "C:\ProgramData\Nimbus\Logs\service-stderr.log"

# Verify config file
Test-Path "C:\Program Files\Nimbus\Autopilot\config.json"
```

### Not sending telemetry?

```powershell
# Test API connectivity
Invoke-RestMethod -Uri "https://your-api-endpoint.com/api/health"

# Check API key
$headers = @{ "X-API-Key" = "your_api_key" }
Invoke-RestMethod -Uri "https://your-api-endpoint.com/api/clients" -Headers $headers
```

### View detailed errors

```powershell
Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-*.log" | Select-String -Pattern "ERROR"
```

---

## For More Details

See **SERVICE-DEPLOYMENT.md** for:
- Advanced configuration
- Security hardening
- Performance tuning
- Intune deployment
- Custom metadata
- Failover endpoints

---

## Quick Reference

| Task | Command |
|------|---------|
| **Install** | `.\Install-TelemetryService.ps1 -ApiEndpoint "URL" -ApiKey "KEY"` |
| **Uninstall** | `.\Uninstall-TelemetryService.ps1` |
| **Service Status** | `Get-Service NimbusAutopilotTelemetry` |
| **Start** | `Start-Service NimbusAutopilotTelemetry` |
| **Stop** | `Stop-Service NimbusAutopilotTelemetry` |
| **Logs** | `Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-*.log" -Tail 50 -Wait` |
| **Config** | `Get-Content "C:\Program Files\Nimbus\Autopilot\config.json"` |
| **State** | `Get-Content "C:\ProgramData\Nimbus\telemetry-state.json"` |

---

## Support

- ?? Full documentation: `SERVICE-DEPLOYMENT.md`
- ?? Issues: Check logs in `C:\ProgramData\Nimbus\Logs`
- ?? Questions: Review main project README.md
