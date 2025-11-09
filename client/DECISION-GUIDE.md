# Running Autopilot Telemetry Continuously - Decision Guide

## TL;DR - Quick Recommendation

**For Production:** Use **Windows Service + Task Scheduler Backup** ?  
**For Testing:** Use **Direct Script Execution**

---

## Detailed Comparison

| Criteria | Windows Service | Task Scheduler Only | Direct Script | Azure Function | Container Service |
|----------|----------------|-------------------|---------------|----------------|------------------|
| **Survives Reboots** | ? Yes | ? Yes | ? No | ?? N/A (cloud) | ?? Depends |
| **Auto-Start on Boot** | ? Yes | ? Yes | ? No | ?? N/A | ?? Depends |
| **State Persistence** | ? Yes | ?? Manual | ? No | ?? External DB | ?? External |
| **Continuous Monitoring** | ? Yes | ?? Interval-based | ? Yes (manual) | ? No | ? Yes |
| **Automatic Recovery** | ? Yes (NSSM) | ? Yes | ? No | ? Yes | ? Yes |
| **Dual-Layer Protection** | ? Service + Task | ? Single | ? Single | ? Single | ? Single |
| **Setup Complexity** | ?? Medium | ?? Low | ?? Very Low | ?? High | ?? High |
| **Resource Usage** | ?? Low | ?? Very Low | ?? Low | ?? Medium | ?? Medium |
| **Management Tools** | Services.msc | Task Scheduler | Manual | Azure Portal | Docker/K8s |
| **Intune Deployment** | ? Win32 App | ? Script | ? Script | ? No | ? No |
| **Logging** | ? Comprehensive | ?? Limited | ?? Limited | ? App Insights | ? Container logs |
| **Heartbeat Support** | ? Yes | ? No | ?? Manual | ?? Manual | ? Yes |
| **Maintenance Mode** | ? Yes | ? No | ? No | ? No | ?? Manual |
| **Production-Ready** | ??? Excellent | ?? Fair | ? Not Recommended | ?? Overkill | ?? Overkill |
| **Cost** | ?? Free | ?? Free | ?? Free | ?? Azure costs | ?? Infra costs |

---

## Option 1: Windows Service + Task Scheduler Backup ? **RECOMMENDED**

### Architecture
```
Windows Service (NSSM)
    ??? Auto-start on boot
    ??? Continuous monitoring loop
    ??? State persistence
    ??? Automatic crash recovery
    ??? Comprehensive logging

Task Scheduler (Backup)
    ??? Runs every 15 minutes
    ??? Ensures service is running
    ??? Independent failsafe
```

### Pros ?
- **Bulletproof reliability** - Dual-layer protection
- **Zero configuration needed after install**
- **Survives all reboot scenarios**
- **State persists across reboots**
- **Automatic recovery from crashes**
- **Professional-grade logging**
- **Easy deployment via Intune**
- **Standard Windows management**

### Cons ?
- **Medium setup complexity** (one-time)
- **Requires NSSM download**
- **Needs admin rights to install**

### Best For ??
- ? Production Autopilot deployments
- ? Enterprise environments
- ? Long-running deployments (hours)
- ? Critical monitoring requirements
- ? Intune-managed devices

### Setup Time
**5 minutes** (automated installer)

### When to Choose
**Always use for production unless you have a specific reason not to.**

---

## Option 2: Task Scheduler Only

### Architecture
```
Task Scheduler
    ??? Trigger: At startup
    ??? Trigger: Every X minutes (repeating)
    ??? Action: Run PowerShell script
```

### Pros ?
- **Simple setup**
- **Built into Windows**
- **Survives reboots**
- **No external dependencies**
- **Easy to modify**

### Cons ?
- **Not truly continuous** (runs at intervals)
- **No built-in crash recovery for script**
- **State persistence requires manual coding**
- **Less comprehensive logging**
- **Gaps between executions**

### Best For ??
- ?? Budget/minimal deployments
- ?? Testing scenarios
- ?? When NSSM cannot be used

### Setup Time
**10 minutes** (manual configuration)

### How to Implement
```powershell
# Create task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\Scripts\Send-AutopilotTelemetry.ps1 -ApiEndpoint 'URL' -ApiKey 'KEY'"

$trigger1 = New-ScheduledTaskTrigger -AtStartup
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 999

Register-ScheduledTask -TaskName "NimbusTelemetry" -Action $action -Trigger @($trigger1, $trigger2) -Settings $settings -User "SYSTEM" -RunLevel Highest
```

### When to Choose
**Only when:**
- Cannot use NSSM
- Truly continuous monitoring not required
- Acceptable to have gaps between telemetry

---

## Option 3: Direct Script Execution

### Architecture
```
PowerShell Script
    ??? Single execution (until process ends)
```

### Pros ?
- **Simplest setup** (just run script)
- **No installation required**
- **Easy to modify and test**
- **Full control**

### Cons ?
- **Does NOT survive reboots** ???
- **No automatic recovery**
- **Manual start required**
- **No state persistence**
- **Process can be killed**

### Best For ??
- ? Testing and development
- ? One-time data collection
- ? Proof-of-concept
- ? Manual execution scenarios
- ?? **NOT for production**

### Setup Time
**30 seconds**

### How to Run
```powershell
.\Send-AutopilotTelemetry.ps1 -ApiEndpoint "URL" -ApiKey "KEY"
```

### When to Choose
**Only for:**
- Testing
- Development
- One-time executions
- Deployments with NO reboots

**? NEVER use for production Autopilot deployments**

---

## Option 4: Azure Function (Cloud-Based)

### Architecture
```
Autopilot Device
    ??? Runs scheduled script
    ??? Calls Azure Function

Azure Function
    ??? Triggered by timer or HTTP
  ??? Queries device via Intune Graph API
    ??? Sends telemetry to database
```

### Pros ?
- **Centralized monitoring**
- **No client-side service needed**
- **Scalable**
- **Cloud-native**

### Cons ?
- **Requires Azure subscription** (cost)
- **Complex setup**
- **API rate limits**
- **Delayed telemetry** (polling-based)
- **Requires Intune/Graph API permissions**
- **Not real-time**

### Best For ??
- ?? Large-scale deployments (1000+ devices)
- ?? When centralized control is required
- ?? When client-side services are prohibited

### Cost
**$$ - Azure Function + Storage + API calls**

### When to Choose
**Only if:**
- Managing 1000+ devices
- Client-side scripts prohibited
- Budget for Azure services
- Delayed telemetry acceptable

---

## Option 5: Container Service (Docker/Kubernetes)

### Architecture
```
Windows Device
    ??? Docker for Windows
        ??? Container running telemetry script
```

### Pros ?
- **Isolated environment**
- **Easy updates** (new container image)
- **Portable**

### Cons ?
- **Docker for Windows required** (not on all Autopilot devices)
- **Higher resource usage**
- **Overkill for simple script**
- **Complex setup**
- **Not standard on Windows clients**

### Best For ??
- ? **NOT recommended for this use case**
- ?? Only if you already have container infrastructure

### When to Choose
**Never** for Autopilot telemetry (unless you have a very specific requirement)

---

## Decision Tree

```
START
  ?
  ?? Is this for PRODUCTION? ???? YES ??? Use Windows Service ?
  ?           + Task Scheduler Backup
  ?
  ?? NO (Testing/Dev)
    ?
  ?? Will device REBOOT? ???? YES ??? Use Windows Service ?
      ?     or Task Scheduler
      ?
      ?? NO (No reboots)
          ?
          ?? Single execution? ??? YES ??? Direct Script ?
```

---

## Deployment Scenarios

### Scenario: Enterprise Autopilot (1000+ devices)

**Recommended:** Windows Service + Task Scheduler Backup

**Deployment Method:** Intune Win32 App

**Why:**
- Reliable across all devices
- Survives reboots during Autopilot
- Easy central deployment
- Comprehensive monitoring

---

### Scenario: Small Business (10-50 devices)

**Recommended:** Windows Service OR Task Scheduler Only

**Deployment Method:** Intune PowerShell Script or Manual

**Why:**
- Still need reliability
- Can afford manual setup if needed
- Task Scheduler acceptable for small scale

---

### Scenario: Testing New Deployment Profile

**Recommended:** Direct Script

**Deployment Method:** Manual execution

**Why:**
- Quick to start
- Easy to modify
- One device at a time
- No permanent installation

---

### Scenario: Pilot Program (50-100 devices)

**Recommended:** Windows Service + Task Scheduler Backup

**Deployment Method:** Intune Win32 App (targeted deployment)

**Why:**
- Production-like environment
- Validates service reliability
- Real-world testing of deployment process

---

## Implementation Roadmap

### Phase 1: Testing (Week 1)
```
Day 1-2: Test direct script on 1-2 devices
Day 3-4: Test Windows Service on 5-10 devices
Day 5: Review logs and telemetry data
```

### Phase 2: Pilot (Week 2-3)
```
Week 2: Deploy service to 50 pilot devices via Intune
Week 3: Monitor, troubleshoot, refine
```

### Phase 3: Production (Week 4+)
```
Week 4: Full rollout to all Autopilot devices
Ongoing: Monitor, maintain, optimize
```

---

## Final Recommendation Matrix

| Your Situation | Recommended Solution |
|----------------|---------------------|
| **Enterprise production** | Windows Service + Task Scheduler ??? |
| **SMB production** | Windows Service + Task Scheduler ?? |
| **Testing/Development** | Direct Script ? |
| **Pilot program** | Windows Service + Task Scheduler ?? |
| **One-time deployment** | Direct Script ? |
| **Large-scale (1000+)** | Windows Service + consider Azure Function for aggregation |
| **Budget/minimal** | Task Scheduler Only ? |

---

## Common Questions

**Q: Can I switch between options later?**  
A: Yes. Start with direct script for testing, then deploy service for production.

**Q: What if I can't use NSSM?**  
A: Use Task Scheduler Only or create a native Windows Service in C#.

**Q: Do I need both service AND task scheduler?**  
A: Task Scheduler is a **backup/failsafe**. Service alone works, but backup adds resilience.

**Q: How much does the service impact device performance?**  
A: Minimal. ~20-40MB RAM, <1% CPU. Negligible for modern devices.

**Q: Can I run multiple telemetry solutions?**  
A: Yes, but not recommended. Choose one to avoid duplicate data.

---

## Get Started

**Ready to implement? Choose your path:**

1. **Windows Service (Recommended):** See [QUICKSTART.md](QUICKSTART.md)
2. **Full Service Guide:** See [SERVICE-DEPLOYMENT.md](SERVICE-DEPLOYMENT.md)
3. **Intune Deployment:** See [INTUNE-DEPLOYMENT.md](INTUNE-DEPLOYMENT.md)
4. **Direct Script:** See [README.md](README.md)
5. **Architecture Overview:** See [SOLUTION-OVERVIEW.md](SOLUTION-OVERVIEW.md)

---

**Still not sure? Start with the direct script for testing, then move to the Windows Service for production.**

**Questions or need help? Review the comprehensive documentation in SERVICE-DEPLOYMENT.md**
