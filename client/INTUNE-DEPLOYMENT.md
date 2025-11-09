# Deploying Nimbus Autopilot Telemetry via Microsoft Intune

## Overview

This guide covers deploying the Nimbus Autopilot Telemetry service to Windows devices using Microsoft Intune as a Win32 app.

## Prerequisites

- **Microsoft Intune** subscription
- **Azure AD Premium** (for Autopilot)
- **Microsoft Win32 Content Prep Tool** ([Download](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool))
- **Nimbus API** endpoint and API key

## Deployment Steps

### Step 1: Prepare Package Files

Create a folder (e.g., `C:\Temp\NimbusPackage`) with these files:

```
NimbusPackage/
??? Install-TelemetryService.ps1
??? Send-AutopilotTelemetry-Service.ps1
??? Send-AutopilotTelemetry.ps1
??? Install.ps1
```

**Create `Install.ps1`** (wrapper script):

```powershell
# Install.ps1 - Intune deployment wrapper
param(
    [Parameter(Mandatory=$false)]
    [string]$ApiEndpoint = "https://your-api-endpoint.com",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = "your_api_key_here",
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentProfile = "Standard"
)

$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Run installation
& "$scriptPath\Install-TelemetryService.ps1" `
    -ApiEndpoint $ApiEndpoint `
    -ApiKey $ApiKey `
    -DeploymentProfile $DeploymentProfile `
    -Verbose

# Exit with appropriate code
if ($LASTEXITCODE -eq 0) {
    Write-Host "Installation completed successfully"
    exit 0
} else {
Write-Error "Installation failed with exit code: $LASTEXITCODE"
    exit 1
}
```

### Step 2: Create .intunewin Package

Download and extract the **Microsoft Win32 Content Prep Tool**.

Run the following command:

```cmd
IntuneWinAppUtil.exe -c "C:\Temp\NimbusPackage" -s "Install.ps1" -o "C:\Temp\IntunePackages"
```

This creates `Install.intunewin` in the output folder.

### Step 3: Upload to Intune

1. **Sign in to [Microsoft Endpoint Manager admin center](https://endpoint.microsoft.com/)**

2. **Navigate to:** Apps ? Windows ? Add

3. **Select app type:** Windows app (Win32)

4. **Click Select** and then **Select app package file**

5. **Upload** `Install.intunewin`

### Step 4: Configure App Information

**Name:** Nimbus Autopilot Telemetry Service
**Description:** Continuous telemetry monitoring for Windows Autopilot deployments  
**Publisher:** Your Organization  
**Category:** Business (optional)  
**Show this as a featured app in the Company Portal:** No  
**Information URL:** (optional)  
**Privacy URL:** (optional)  
**Developer:** (optional)  
**Owner:** (optional)  
**Notes:** (optional)  
**Logo:** (optional - upload PNG/JPG)

**Click Next**

### Step 5: Configure Program Settings

**Install command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File Install.ps1 -ApiEndpoint "https://your-api-endpoint.com" -ApiKey "your_api_key_here" -DeploymentProfile "Standard"
```

**Uninstall command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File Uninstall-TelemetryService.ps1
```

**Install behavior:** System

**Device restart behavior:** No specific action

**Return codes:**
- 0 = Success
- 1707 = Success (reboot required)
- 3010 = Soft reboot
- 1641 = Hard reboot
- 1 = Failed

**Click Next**

### Step 6: Configure Requirements

**Operating system architecture:** 64-bit  
**Minimum operating system:** Windows 10 1607  

**Additional requirements (optional):**
- Disk space: 50 MB
- Physical memory: 100 MB
- Processor: 1 GHz

**Click Next**

### Step 7: Configure Detection Rules

**Rules format:** Manually configure detection rules

**Add Rule:**
- **Rule type:** Registry
- **Key path:** `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NimbusAutopilotTelemetry`
- **Value name:** (leave blank - detect key existence)
- **Detection method:** Key exists
- **Associated with a 32-bit app on 64-bit clients:** No

**Alternative Detection Rule (File-based):**
- **Rule type:** File
- **Path:** `C:\Program Files\Nimbus\Autopilot`
- **File or folder:** `config.json`
- **Detection method:** File or folder exists
- **Associated with a 32-bit app on 64-bit clients:** No

**Click Next**

### Step 8: Configure Dependencies

**None required** (all dependencies are self-contained)

**Click Next**

### Step 9: Configure Supersedence

**None required** (first deployment)

**Click Next**

### Step 10: Assignments

#### Required Deployment (Recommended)

**Assign to:** All Devices (or specific Autopilot device groups)

**Mode:** Required

**Assignment purpose:** Ensure all Autopilot devices have telemetry service

#### Available Deployment (Alternative)

**Assign to:** Specific device groups

**Mode:** Available for enrolled devices

**End users can install from Company Portal:** No (this is a background service)

**Click Next**

### Step 11: Review + Create

Review all settings and click **Create**

---

## Deployment Timeline

| Phase | Timing | Description |
|-------|--------|-------------|
| **App Upload** | Immediate | App package uploaded to Intune |
| **Policy Sync** | ~8 hours | Devices check for new policies |
| **Download** | 5-10 min | App downloaded to device |
| **Installation** | 2-5 min | Service installed and started |
| **First Telemetry** | 30 sec | First telemetry sent to API |

**To expedite:** Force sync on device via Company Portal or:
```powershell
Get-ScheduledTask | Where-Object {$_.TaskName -eq 'PushLaunch'} | Start-ScheduledTask
```

---

## Monitoring Deployment

### View Deployment Status in Intune

1. Navigate to **Apps ? Windows**
2. Click on **Nimbus Autopilot Telemetry Service**
3. Select **Device install status** or **User install status**

### Check Individual Device

1. Navigate to **Devices ? Windows**
2. Select specific device
3. Click **Managed Apps**
4. Find **Nimbus Autopilot Telemetry Service**
5. View installation status and error codes

### Common Status Codes

| Code | Status | Description |
|------|--------|-------------|
| **0** | Success | Installation completed successfully |
| **1** | Failed | Installation failed (check logs) |
| **2016281112** | Not Applicable | Requirements not met |
| **2016330751** | Pending | Download in progress |
| **2016330752** | Pending | Installation in progress |

---

## Troubleshooting Intune Deployment

### App Not Installing

**Check:**
1. **Device enrollment:** Ensure device is enrolled in Intune
2. **Assignment:** Verify device is in assigned group
3. **Requirements:** Check OS version and architecture match
4. **Network:** Ensure device can reach Intune and download content

**View Intune Management Extension logs on device:**
```
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log
```

### Installation Fails

**Check device logs:**
```powershell
# View installation log
Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" | Select-String -Pattern "Nimbus"

# View service installation errors
Get-Content "C:\ProgramData\Nimbus\Logs\service-stderr.log"
```

**Common Issues:**
- **API endpoint unreachable:** Verify URL and network connectivity
- **Invalid API key:** Check API key in install command
- **PowerShell execution policy:** Ensure `-ExecutionPolicy Bypass` is in install command
- **Insufficient permissions:** Service installation requires SYSTEM or admin rights

### Reinstall App

1. In Intune, change assignment to **Available**
2. On device, uninstall from Company Portal
3. Wait 5 minutes
4. Change assignment back to **Required**
5. Force policy sync on device

---

## Advanced Configuration

### Using Azure Key Vault for API Key

**Instead of hardcoding API key in install command:**

1. **Store API key in Azure Key Vault**

2. **Grant device Managed Identity access to Key Vault**

3. **Modify Install.ps1 to retrieve key:**

```powershell
# Install.ps1 (modified)
$keyVaultName = "your-keyvault"
$secretName = "NimbusApiKey"

# Get API key from Key Vault using device Managed Identity
$apiKey = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText)

# Run installation with retrieved key
& "$scriptPath\Install-TelemetryService.ps1" `
    -ApiEndpoint $ApiEndpoint `
    -ApiKey $apiKey `
    -DeploymentProfile $DeploymentProfile
```

4. **Update Intune install command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -NoProfile -File Install.ps1 -ApiEndpoint "https://your-api-endpoint.com" -DeploymentProfile "Standard"
```

### Environment-Specific Configuration

**Deploy different configurations based on device group:**

1. **Create multiple Win32 apps:**
   - Nimbus Telemetry (Production)
   - Nimbus Telemetry (Staging)
   - Nimbus Telemetry (Development)

2. **Each with different install commands:**
   ```powershell
   # Production
   -ApiEndpoint "https://api.prod.yourdomain.com" -ApiKey "prod_key"
   
   # Staging
   -ApiEndpoint "https://api.staging.yourdomain.com" -ApiKey "staging_key"
   
   # Development
   -ApiEndpoint "https://api.dev.yourdomain.com" -ApiKey "dev_key"
   ```

3. **Assign to respective device groups**

### Dynamic Group Assignment

**Assign based on Autopilot profile:**

1. **Create dynamic device group in Azure AD:**
   ```
   Name: Autopilot - Standard Profile
   Type: Dynamic Device
Dynamic query:
   (device.enrollmentProfileName -eq "Standard")
   ```

2. **Assign app to this group**

3. **Devices with "Standard" profile automatically get the app**

---

## Autopilot Integration

### Deploy During Autopilot ESP

**To ensure telemetry starts during Autopilot:**

1. **Assign app as Required to Autopilot device group**

2. **Configure app to install during Device ESP:**
   - Set **Available for enrolled devices** to **No**
   - Ensure assignment target includes Autopilot devices

3. **App installs during "Device Setup" phase**

4. **Telemetry starts reporting immediately**

### Pre-Provision Scenarios

**For Autopilot Pre-Provisioning (White Glove):**

1. App installs during technician provisioning
2. Service starts and begins monitoring
3. State persists when device is shipped to end user
4. Continues monitoring during user ESP

---

## Compliance and Reporting

### Create Compliance Policy

**Ensure service is installed on all devices:**

1. **Navigate to:** Devices ? Compliance policies ? Create Policy

2. **Platform:** Windows 10 and later

3. **Settings ? System Security:**
   - Custom compliance settings: Use PowerShell script

4. **Detection script:**
```powershell
$service = Get-Service -Name "NimbusAutopilotTelemetry" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Output "Compliant"
    exit 0
} else {
    Write-Output "Non-Compliant"
    exit 1
}
```

5. **Assign to device groups**

### Generate Reports

**App installation report:**
1. Navigate to **Apps ? Monitor ? App install status**
2. Select **Nimbus Autopilot Telemetry Service**
3. Export to CSV

**Custom report via Microsoft Graph API:**
```powershell
# Get all devices with app installation status
$appId = "your-app-id"
$uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/deviceStatuses"
$result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
$result.value | Export-Csv -Path "app-deployment-report.csv"
```

---

## Updating the Service

### Deploy New Version

1. **Prepare new package** with updated scripts

2. **Create new .intunewin** package

3. **Two options:**

   **Option A: Create new app**
   - Upload new app to Intune
   - Configure as superseding previous version
   - Intune automatically upgrades

   **Option B: Update existing app**
 - Edit existing app in Intune
   - Replace app package file
   - Increment version number
   - Devices automatically update on next sync

### Force Update

**Remove and reinstall:**
1. Change assignment to **Uninstall**
2. Wait for uninstall to complete
3. Change assignment back to **Required** with new version

---

## Best Practices

? **Use dynamic groups** for automatic assignment to Autopilot devices  
? **Store API keys securely** in Azure Key Vault  
? **Test in pilot group** before broad deployment  
? **Monitor installation status** regularly  
? **Create compliance policy** to ensure service is running  
? **Document custom configurations** for your environment  
? **Set up alerts** for installation failures  
? **Keep detection rules simple** and reliable  
? **Use HTTPS endpoints** for API communication  
? **Version your packages** for easier rollback  

---

## Sample Intune Scripts

### Detection Script (Advanced)

```powershell
# Advanced detection with version check
$expectedVersion = "1.0"
$serviceName = "NimbusAutopilotTelemetry"
$configPath = "C:\Program Files\Nimbus\Autopilot\config.json"

try {
    # Check service exists and is running
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.Status -ne "Running") {
        exit 1
    }
    
    # Check config file exists
    if (-not (Test-Path $configPath)) {
 exit 1
    }
    
    # Optional: Check version
    # Add version to config.json and verify
    
    # All checks passed
    exit 0
}
catch {
    exit 1
}
```

### Remediation Script (Proactive Remediation)

**Detection:**
```powershell
$service = Get-Service -Name "NimbusAutopilotTelemetry" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Output "Service is running"
    exit 0
} else {
    Write-Output "Service is not running"
    exit 1
}
```

**Remediation:**
```powershell
try {
    Start-Service -Name "NimbusAutopilotTelemetry" -ErrorAction Stop
    Write-Output "Service started successfully"
    exit 0
}
catch {
    Write-Error "Failed to start service: $_"
    exit 1
}
```

---

## Support and Resources

- **Intune Documentation:** [Microsoft Docs](https://docs.microsoft.com/en-us/mem/intune/)
- **Win32 App Management:** [Guide](https://docs.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management)
- **Troubleshooting:** Check `IntuneManagementExtension.log` on device
- **Service Logs:** `C:\ProgramData\Nimbus\Logs\`

---

## Frequently Asked Questions

**Q: Can I deploy without Intune?**  
A: Yes, see SERVICE-DEPLOYMENT.md for manual installation, GPO, or other methods.

**Q: How do I change the API endpoint after deployment?**  
A: Edit `C:\Program Files\Nimbus\Autopilot\config.json` and restart the service.

**Q: Does this work with Autopilot for existing devices?**  
A: Yes, the service works with all Autopilot scenarios.

**Q: Can I deploy to Windows 11 only?**  
A: Yes, adjust the OS requirements in Step 6 to Windows 11.

**Q: What happens if the device is offline?**  
A: Service continues running and queues telemetry. When online, it resumes sending data.

**Q: How do I uninstall via Intune?**  
A: Change assignment from Required to **Uninstall** for target devices.

---

**Last Updated:** January 2024  
**Version:** 1.0
