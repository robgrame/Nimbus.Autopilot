# Nimbus Autopilot Telemetry Client

PowerShell-based telemetry client for monitoring Windows Autopilot Enrollment Status Page (ESP) progress.

## Deployment Options

### ?? **Option 1: Windows Service (Recommended for Production)**

**Best for:** Production deployments requiring automatic startup, reboot survival, and continuous monitoring.

**Features:**
- ? Automatic startup on device boot
- ? Survives reboots with state persistence
- ? Self-healing with automatic restart on failure
- ? Task Scheduler backup for redundancy
- ? Heartbeat monitoring
- ? Maintenance mode after deployment completion

**Quick Install:**
```powershell
.\Install-TelemetryService.ps1 `
    -ApiEndpoint "https://api.yourdomain.com" `
    -ApiKey "your_api_key"
```

**?? See [QUICKSTART.md](QUICKSTART.md) for 5-minute setup guide**  
**?? See [SERVICE-DEPLOYMENT.md](SERVICE-DEPLOYMENT.md) for complete documentation**

---

### ?? **Option 2: Direct Script Execution**

**Best for:** Testing, one-time deployments, or custom integration scenarios.

**Usage:**
```powershell
.\Send-AutopilotTelemetry.ps1 -ApiKey "your_api_key_here"
```

**Note:** This option does NOT survive reboots. For production, use the Windows Service option above.

---

## Features

- **Automated Monitoring**: Continuously monitors Autopilot ESP progress
- **Phase Detection**: Automatically detects current deployment phase
- **Progress Tracking**: Tracks progress percentage through deployment stages
- **Error Handling**: Robust error handling with retry logic
- **Minimal Footprint**: Lightweight PowerShell script with no dependencies
- **Logging**: Comprehensive logging for troubleshooting

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Network connectivity to Nimbus API endpoint
- Administrator privileges (for accessing ESP registry keys)

## Usage

### Basic Usage

```powershell
.\Send-AutopilotTelemetry.ps1 -ApiKey "your_api_key_here"
```

### Full Configuration

```powershell
.\Send-AutopilotTelemetry.ps1 `
    -ApiEndpoint "https://api.yourdomain.com" `
    -ApiKey "your_api_key_here" `
    -ClientId "CUSTOM-ID-001" `
    -DeploymentProfile "Standard" `
    -IntervalSeconds 30 `
    -MaxRetries 3
```

### Parameters

- **ApiEndpoint**: URL of the Nimbus API (default: `http://localhost:5000`)
- **ApiKey**: API key for authentication (required)
- **ClientId**: Unique identifier for the device (default: auto-generated from computer name and serial number)
- **DeploymentProfile**: Name of the Autopilot deployment profile (default: `Standard`)
- **IntervalSeconds**: Interval between telemetry submissions in seconds (default: `30`)
- **MaxRetries**: Maximum number of retry attempts for failed API calls (default: `3`)

## Deployment

### Manual Deployment

1. Copy the script to the device during imaging or provisioning
2. Create a scheduled task to run at startup with admin privileges
3. Configure the parameters via script arguments or configuration file

### Intune Deployment

Deploy via Intune as a Win32 app or PowerShell script:

**Install Command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File Send-AutopilotTelemetry.ps1 -ApiEndpoint "https://api.yourdomain.com" -ApiKey "your_api_key"
```

**Detection Rule:**
- File: `C:\ProgramData\Nimbus\Logs\telemetry-*.log`

### Autopilot Integration

Add to Autopilot deployment profile as a provisioning package or deploy via Intune after device enrollment begins.

## Monitored Phases

The client monitors and reports the following deployment phases:

1. **Device Preparation**: Initial device setup
2. **Device Setup**: Core device configuration
3. **Account Setup**: User account configuration
4. **Apps Installation**: Application deployment
5. **Policies Application**: Security and configuration policies
6. **Completion**: Deployment finished

## Telemetry Data

The client sends the following data to the API:

```json
{
  "client_id": "DEVICE-12345",
  "device_name": "LAPTOP-ABC",
  "deployment_profile": "Standard",
  "phase_name": "Device Setup",
  "event_type": "progress",
  "event_timestamp": "2024-01-15T10:30:00Z",
  "progress_percentage": 45,
  "status": "in_progress",
  "duration_seconds": 120,
  "error_message": null,
  "metadata": {
    "esp_active": true,
    "enrollment_state": 2,
    "os_version": "10.0.22621.0"
  }
}
```

## Logging

Logs are stored in `C:\ProgramData\Nimbus\Logs\telemetry-YYYYMMDD.log`

Log entries include:
- Timestamp
- Log level (INFO, ERROR)
- Message details

Example log entries:
```
[2024-01-15 10:30:00] [INFO] Starting Nimbus Autopilot Telemetry Client
[2024-01-15 10:30:00] [INFO] Client ID: LAPTOP-ABC-SN123456
[2024-01-15 10:30:30] [INFO] Sending telemetry: progress - Phase: Device Setup - Progress: 45%
[2024-01-15 10:30:31] [INFO] Telemetry sent successfully. Event ID: 12345
```

## Error Handling

The client implements:
- **Exponential Backoff**: Retries with increasing delays on failure
- **Maximum Retries**: Configurable retry limit (default: 3 attempts)
- **Graceful Degradation**: Continues monitoring even if API calls fail
- **Error Logging**: All errors logged for troubleshooting

## Troubleshooting

### Client Not Sending Data

1. Check network connectivity to API endpoint
2. Verify API key is correct
3. Review logs in `C:\ProgramData\Nimbus\Logs`
4. Ensure PowerShell execution policy allows script execution
5. Verify administrator privileges

### Permission Issues

Run PowerShell as Administrator:
```powershell
Start-Process powershell -Verb RunAs
```

### Testing Connectivity

Test API connectivity:
```powershell
Invoke-RestMethod -Uri "http://your-api-endpoint/api/health"
```

## Security Considerations

- **API Key**: Store API key securely, avoid hardcoding in scripts
- **HTTPS**: Use HTTPS endpoints in production
- **Permissions**: Script requires admin privileges for registry access
- **Logging**: Logs may contain sensitive device information

## Best Practices

1. Use HTTPS endpoints for production deployments
2. Rotate API keys regularly
3. Monitor log files for errors
4. Test in a non-production environment first
5. Configure appropriate telemetry interval for your network
6. Clean up old log files periodically
