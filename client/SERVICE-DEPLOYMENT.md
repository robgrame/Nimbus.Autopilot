# Nimbus Autopilot Telemetry - Service Deployment Guide

## Overview

The Nimbus Autopilot Telemetry service provides a robust, production-ready solution for continuously monitoring Autopilot device deployments with automatic recovery from reboots and failures.

## Architecture

```
???????????????????????????????????????????
?        Windows Service (NSSM)  ?
?  ??????????????????????????????????????  ?
?  ? Send-AutopilotTelemetry-Service.ps1?  ?
?  ?  - Continuous monitoring loop      ?  ?
?  ?  - State persistence         ?  ?
?  ?  - Automatic restart on failure    ?  ?
?  ??????????????????????????????????????  ?
???????????????????????????????????????????
     ?
   ?? HTTPS/JSON ???? Nimbus API
           ?
       ??????????????????
       ?  Backup Layer   ?
  ?  Task Scheduler ?
       ?  (Runs every   ?
       ?   15 minutes)   ?
       ??????????????????
```

### Key Features

? **Survives Reboots** - Service starts automatically on boot  
? **State Persistence** - Maintains deployment state across restarts  
? **Auto-Recovery** - Automatic restart on crashes  
? **Dual-Layer Protection** - Service + Task Scheduler backup  
? **Heartbeat Monitoring** - Regular health checks  
? **Maintenance Mode** - Continues monitoring after deployment completion  
? **Comprehensive Logging** - Detailed logs for troubleshooting  

## Installation

### Prerequisites

- **Windows 10/11** or Windows Server 2016+
- **PowerShell 5.1** or later
- **Administrator privileges**
- **Network access** to Nimbus API endpoint

### Quick Install

```powershell
# Run as Administrator
.\Install-TelemetryService.ps1 `
-ApiEndpoint "https://api.yourdomain.com" `
    -ApiKey "your_api_key_here" `
    -DeploymentProfile "Standard" `
 -IntervalSeconds 30
```

### Installation Steps

The installation script performs:

1. **Creates installation directory** (`C:\Program Files\Nimbus\Autopilot`)
2. **Copies PowerShell scripts**
3. **Creates configuration file** (encrypted API key storage recommended for production)
4. **Downloads and installs NSSM** (Non-Sucking Service Manager)
5. **Installs Windows Service** with auto-start configuration
6. **Creates Task Scheduler backup** task
7. **Starts the service**

### Installation Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ApiEndpoint` | Yes | - | Nimbus API base URL |
| `ApiKey` | Yes | - | API authentication key |
| `DeploymentProfile` | No | "Standard" | Autopilot deployment profile name |
| `IntervalSeconds` | No | 30 | Telemetry submission interval |
| `ServiceName` | No | "NimbusAutopilotTelemetry" | Windows Service name |
| `InstallPath` | No | "C:\Program Files\Nimbus\Autopilot" | Installation directory |

## Service Management

### Check Service Status

```powershell
Get-Service -Name NimbusAutopilotTelemetry
```

### Start/Stop Service

```powershell
# Start
Start-Service -Name NimbusAutopilotTelemetry

# Stop
Stop-Service -Name NimbusAutopilotTelemetry

# Restart
Restart-Service -Name NimbusAutopilotTelemetry
```

### View Service Logs

```powershell
# View main telemetry log (live tail)
Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-$(Get-Date -Format 'yyyyMMdd').log" -Tail 50 -Wait

# View service stdout log
Get-Content "C:\ProgramData\Nimbus\Logs\service-stdout.log" -Tail 50 -Wait

# View service stderr log
Get-Content "C:\ProgramData\Nimbus\Logs\service-stderr.log" -Tail 50 -Wait
```

### View Service Configuration

```powershell
# Using NSSM
& "C:\Program Files\Nimbus\Autopilot\nssm.exe" dump NimbusAutopilotTelemetry

# View configuration file
Get-Content "C:\Program Files\Nimbus\Autopilot\config.json" | ConvertFrom-Json
```

## State Persistence

The service maintains state across reboots in:

**State File:** `C:\ProgramData\Nimbus\telemetry-state.json`

**Tracked Information:**
- Deployment start time
- Last successful telemetry send
- Last event ID
- Last phase and progress

### View Current State

```powershell
Get-Content "C:\ProgramData\Nimbus\telemetry-state.json" | ConvertFrom-Json
```

Example state:
```json
{
  "DeploymentStartTime": "2024-01-15T09:00:00.0000000Z",
  "LastSuccessfulSend": "2024-01-15T10:30:00.0000000Z",
  "LastEventId": 12345,
  "LastPhase": "Apps Installation",
  "LastProgress": 60
}
```

## Task Scheduler Backup

### View Backup Task

```powershell
Get-ScheduledTask -TaskName "NimbusAutopilotTelemetry-Backup"
```

### Task Configuration

- **Triggers:**
  - At system startup
  - Every 15 minutes (repeating)
- **Action:** Run telemetry PowerShell script
- **Principal:** SYSTEM account
- **Settings:**
  - Start if on batteries
  - Don't stop if going on batteries
  - Start when available
  - Restart on failure (up to 999 times)

### Manually Run Backup Task

```powershell
Start-ScheduledTask -TaskName "NimbusAutopilotTelemetry-Backup"
```

## Deployment Scenarios

### Scenario 1: Intune Deployment

**Create Win32 App Package:**

1. Package the following files:
   - `Install-TelemetryService.ps1`
   - `Send-AutopilotTelemetry-Service.ps1`
   - `Send-AutopilotTelemetry.ps1`

2. **Install Command:**
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File Install-TelemetryService.ps1 -ApiEndpoint "https://api.yourdomain.com" -ApiKey "your_api_key"
   ```

3. **Uninstall Command:**
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File Uninstall-TelemetryService.ps1
   ```

4. **Detection Rule:**
   - Registry: `HKLM\SYSTEM\CurrentControlSet\Services\NimbusAutopilotTelemetry`
   - Exists: Yes

### Scenario 2: Provisioning Package

Include the installation script in a provisioning package (`.ppkg`) applied during OOBE.

### Scenario 3: Group Policy Startup Script

Deploy via GPO as a computer startup script with appropriate parameters.

### Scenario 4: Manual Installation

Run the installation script manually on each device (for testing or small deployments).

## Monitoring & Alerting

### Health Checks

The service sends heartbeat events every 5 minutes with:
- Service uptime
- OS version
- Session start time

### Monitor Service Health

```powershell
# Check service status
$service = Get-Service -Name NimbusAutopilotTelemetry
if ($service.Status -ne "Running") {
    Write-Warning "Service is not running!"
}

# Check recent log entries
$recentErrors = Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-*.log" | 
    Select-String -Pattern "\[ERROR\]" | 
    Select-Object -Last 10
```

### Event Viewer

Service events are logged to Windows Event Viewer under:
- **Application Log** - General service events
- **System Log** - Service start/stop events

View with:
```powershell
Get-EventLog -LogName Application -Source "NimbusAutopilotTelemetry" -Newest 50
```

## Troubleshooting

### Service Won't Start

**Check:**
1. **Configuration file exists:**
   ```powershell
   Test-Path "C:\Program Files\Nimbus\Autopilot\config.json"
   ```

2. **Valid JSON configuration:**
   ```powershell
   Get-Content "C:\Program Files\Nimbus\Autopilot\config.json" | ConvertFrom-Json
   ```

3. **NSSM is present:**
   ```powershell
   Test-Path "C:\Program Files\Nimbus\Autopilot\nssm.exe"
   ```

4. **Service error logs:**
```powershell
   Get-Content "C:\ProgramData\Nimbus\Logs\service-stderr.log" -Tail 50
   ```

### Telemetry Not Sending

**Check:**
1. **Network connectivity:**
   ```powershell
   Test-NetConnection api.yourdomain.com -Port 443
   ```

2. **API endpoint reachable:**
   ```powershell
   Invoke-RestMethod -Uri "https://api.yourdomain.com/api/health"
   ```

3. **API key valid:**
   ```powershell
   $headers = @{ "X-API-Key" = "your_api_key" }
   Invoke-RestMethod -Uri "https://api.yourdomain.com/api/clients" -Headers $headers
   ```

4. **Review error logs:**
   ```powershell
   Get-Content "C:\ProgramData\Nimbus\Logs\telemetry-*.log" | Select-String -Pattern "ERROR"
   ```

### Service Consuming Too Much Memory/CPU

**Actions:**
1. **Increase telemetry interval:**
   ```powershell
   # Edit config.json
   $config = Get-Content "C:\Program Files\Nimbus\Autopilot\config.json" | ConvertFrom-Json
   $config.IntervalSeconds = 60  # Increase from 30 to 60 seconds
   $config | ConvertTo-Json | Set-Content "C:\Program Files\Nimbus\Autopilot\config.json"
   
   # Restart service
   Restart-Service -Name NimbusAutopilotTelemetry
   ```

2. **Check for log file rotation:**
   ```powershell
   Get-ChildItem "C:\ProgramData\Nimbus\Logs" | Sort-Object Length -Descending
   ```

### Manually Stop Service

Create a stop signal file:
```powershell
New-Item -Path "C:\ProgramData\Nimbus\stop-service.signal" -ItemType File -Force
```

The service will gracefully stop on the next loop iteration.

## Uninstallation

### Standard Uninstall

```powershell
.\Uninstall-TelemetryService.ps1
```

### Keep Logs and Configuration

```powershell
.\Uninstall-TelemetryService.ps1 -KeepLogs -KeepConfig
```

### Manual Cleanup

If uninstall script is not available:

```powershell
# Stop and remove service
Stop-Service -Name NimbusAutopilotTelemetry
sc.exe delete NimbusAutopilotTelemetry

# Remove task
Unregister-ScheduledTask -TaskName "NimbusAutopilotTelemetry-Backup" -Confirm:$false

# Remove files
Remove-Item -Path "C:\Program Files\Nimbus\Autopilot" -Recurse -Force
Remove-Item -Path "C:\ProgramData\Nimbus" -Recurse -Force
```

## Security Considerations

### Protect API Key

**Production Recommendation:**
- Store API key in **Azure Key Vault** or **Windows Credential Manager**
- Use **Managed Identity** for authentication (if hosted on Azure VM)
- Encrypt configuration file using **DPAPI**

**Example using Windows Credential Manager:**
```powershell
# Store API key securely
$apiKey = "your_api_key"
cmdkey /generic:NimbusApiKey /user:NimbusService /pass:$apiKey

# Retrieve in service script
$credManager = New-Object -TypeName PSCredential -ArgumentList "NimbusService", (ConvertTo-SecureString -String "dummy" -AsPlainText -Force)
$apiKey = (Get-StoredCredential -Target "NimbusApiKey").Password
```

### Service Account

The service runs as **SYSTEM** by default. For enhanced security:
- Create a dedicated **service account** with minimal privileges
- Grant only necessary registry and file system permissions
- Use **Managed Service Account** (gMSA) in domain environments

### Network Security

- Use **HTTPS only** for API communication
- Configure **firewall rules** to allow outbound HTTPS
- Consider **certificate pinning** for API endpoint

## Performance Tuning

### Optimize Telemetry Interval

```powershell
# Low-impact (production)
IntervalSeconds = 60  # Check every minute

# Balanced (recommended)
IntervalSeconds = 30  # Check every 30 seconds

# High-frequency (testing/critical deployments)
IntervalSeconds = 10  # Check every 10 seconds
```

### Log Rotation

NSSM automatically rotates logs when they reach **1MB**. Adjust if needed:

```powershell
& "C:\Program Files\Nimbus\Autopilot\nssm.exe" set NimbusAutopilotTelemetry AppRotateBytes 5242880  # 5MB
```

### Cleanup Old Logs

Create a scheduled task to clean up logs older than 30 days:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command `"Get-ChildItem 'C:\ProgramData\Nimbus\Logs' -Recurse -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force`""

$trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"

Register-ScheduledTask -TaskName "CleanupNimbusLogs" -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest
```

## Best Practices

1. ? **Test in non-production** before deploying to production devices
2. ? **Monitor service health** regularly
3. ? **Set up alerting** for service failures
4. ? **Rotate API keys** periodically
5. ? **Keep logs** for at least 30 days for troubleshooting
6. ? **Document custom configurations**
7. ? **Use HTTPS** in production
8. ? **Implement retry logic** in API client
9. ? **Test recovery** from various failure scenarios
10. ? **Keep service scripts updated** with latest version

## Advanced Configuration

### Custom Client ID

By default, the Client ID is `COMPUTERNAME-SERIALNUMBER`. To customize:

1. Edit the service script:
```powershell
# In Send-AutopilotTelemetry-Service.ps1, modify:
   $ClientId = "CUSTOM-PREFIX-$SerialNumber"
   ```

2. Restart service after changes

### Multiple API Endpoints (Failover)

Modify the service script to support failover:

```powershell
$ApiEndpoints = @(
    "https://api-primary.yourdomain.com",
    "https://api-secondary.yourdomain.com"
)

foreach ($endpoint in $ApiEndpoints) {
    try {
        # Try sending to this endpoint
        $response = Invoke-RestMethod -Uri "$endpoint/api/telemetry" ...
   break  # Success, exit loop
    } catch {
        Write-Log "Endpoint $endpoint failed, trying next..." "WARN"
    }
}
```

### Custom Metadata

Add custom metadata to all telemetry events:

```powershell
# In Send-AutopilotTelemetry-Service.ps1, add to metadata:
metadata = @{
    # ... existing metadata ...
    custom_field_1 = "value"
    custom_field_2 = (Get-ItemProperty "HKLM:\SOFTWARE\YourCompany\Config").Value
    location = "Office-NYC"
}
```

## Support

For issues or questions:
- Review logs in `C:\ProgramData\Nimbus\Logs`
- Check Event Viewer for service events
- Verify API connectivity and authentication
- Consult main project README.md

## Version History

- **v1.0** - Initial release with Windows Service and Task Scheduler backup
