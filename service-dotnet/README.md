# Nimbus Autopilot Telemetry - Windows Service .NET

## Overview

Questo è un **Windows Service nativo** scritto in **.NET Framework 4.8** per il monitoraggio continuo dei deployment Windows Autopilot.

### Vantaggi rispetto alla soluzione PowerShell

| Caratteristica | .NET Service | PowerShell + NSSM |
|----------------|--------------|-------------------|
| **Tool esterni** | ? Nessuno | ? Richiede NSSM |
| **Prestazioni** | ? Ottime | ?? Buone |
| **Memoria** | ? ~15-20 MB | ?? ~40-50 MB |
| **Logging** | ? Event Log nativo | ?? File log |
| **Gestione** | ? Services.msc standard | ? Services.msc |
| **Compatibilità** | ? .NET 4.8 (già installato) | ? PowerShell 5.1+ |
| **Enterprise-Ready** | ??? | ?? |
| **Debug** | ? Visual Studio | ?? Più complesso |

---

## Requisiti

- **Windows 10 versione 1903+** o **Windows 11** (hanno .NET Framework 4.8 preinstallato)
- **Privilegi amministratore** per installazione
- **Accesso di rete** all'endpoint API Nimbus

---

## Build del Progetto

### Opzione 1: Build con Visual Studio

1. Apri `Nimbus.Autopilot.TelemetryService.csproj` in Visual Studio
2. Seleziona configurazione **Release**
3. Build ? Publish
4. L'output sarà in `bin\Release\net48\publish\`

### Opzione 2: Build con .NET CLI

```powershell
cd service-dotnet\Nimbus.Autopilot.TelemetryService

# Build Release
dotnet build -c Release

# Oppure Publish (crea tutti i file necessari)
dotnet publish -c Release -o ..\..\publish\service
```

L'output della build include:
```
publish\service\
??? Nimbus.Autopilot.TelemetryService.exe
??? appsettings.json
??? *.dll (dipendenze)
??? *.pdb (debug symbols - opzionale)
```

---

## Installazione

### Metodo 1: Script PowerShell (Raccomandato)

```powershell
# Esegui come Administrator
.\Install-DotNetService.ps1 `
  -ApiEndpoint "https://api.yourdomain.com" `
 -ApiKey "your_api_key_here" `
-ServiceExecutable "C:\path\to\publish\service\Nimbus.Autopilot.TelemetryService.exe"
```

### Metodo 2: Installazione Manuale

```powershell
# 1. Copia i file
Copy-Item -Path "publish\service\*" -Destination "C:\Program Files\Nimbus\AutopilotService" -Recurse

# 2. Modifica appsettings.json con il tuo API endpoint e key

# 3. Crea il servizio
sc.exe create NimbusAutopilotTelemetry binPath= "C:\Program Files\Nimbus\AutopilotService\Nimbus.Autopilot.TelemetryService.exe" start= auto

# 4. Configura descrizione
sc.exe description NimbusAutopilotTelemetry "Monitors Autopilot deployment progress"

# 5. Configura failure actions
sc.exe failure NimbusAutopilotTelemetry reset= 86400 actions= restart/5000/restart/10000/restart/30000

# 6. Avvia il servizio
Start-Service -Name NimbusAutopilotTelemetry
```

---

## Configurazione

Il file `appsettings.json` contiene tutte le configurazioni:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
 },
    "EventLog": {
      "SourceName": "Nimbus Autopilot Telemetry",
      "LogName": "Application"
    }
  },
  "TelemetrySettings": {
    "ApiEndpoint": "https://api.yourdomain.com",
    "ApiKey": "your_api_key_here",
    "DeploymentProfile": "Standard",
    "IntervalSeconds": 30,
    "HeartbeatIntervalSeconds": 300,
    "MaxRetries": 3
  }
}
```

### Parametri

| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `ApiEndpoint` | - | URL base dell'API Nimbus (richiesto) |
| `ApiKey` | - | Chiave API per autenticazione (richiesto) |
| `DeploymentProfile` | "Standard" | Nome del profilo Autopilot |
| `IntervalSeconds` | 30 | Intervallo tra invii telemetria (secondi) |
| `HeartbeatIntervalSeconds` | 300 | Intervallo heartbeat (5 minuti) |
| `MaxRetries` | 3 | Numero massimo di retry per API call |

---

## Gestione del Servizio

### Comandi PowerShell

```powershell
# Stato del servizio
Get-Service -Name NimbusAutopilotTelemetry

# Start
Start-Service -Name NimbusAutopilotTelemetry

# Stop
Stop-Service -Name NimbusAutopilotTelemetry

# Restart
Restart-Service -Name NimbusAutopilotTelemetry

# Visualizza log eventi
Get-EventLog -LogName Application -Source "Nimbus Autopilot Telemetry" -Newest 50

# Visualizza stato persistente
Get-Content "$env:ProgramData\Nimbus\telemetry-state.json" | ConvertFrom-Json
```

### Services.msc

1. Apri `services.msc`
2. Trova "Nimbus Autopilot Telemetry"
3. Click destro per Start/Stop/Restart
4. Properties per configurazioni avanzate

---

## Logging

### Event Viewer

Il servizio scrive tutti i log nel **Windows Event Log**:

1. Apri **Event Viewer** (eventvwr.msc)
2. Navigate to: **Windows Logs ? Application**
3. Filter by Source: **"Nimbus Autopilot Telemetry"**

**Tipi di log:**
- **Information**: Operazioni normali, telemetria inviata
- **Warning**: Retry, problemi temporanei
- **Error**: Errori che richiedono attenzione

### Livelli di Log

Modifica in `appsettings.json`:
```json
"LogLevel": {
  "Default": "Debug",  // Trace, Debug, Information, Warning, Error, Critical
  "Microsoft": "Warning"
}
```

---

## State Persistence

Il servizio mantiene lo stato in:
```
C:\ProgramData\Nimbus\telemetry-state.json
```

**Contenuto:**
```json
{
  "DeploymentStartTime": "2024-01-15T09:00:00.0000000Z",
  "LastPhase": "Apps Installation",
  "LastProgress": 60,
  "LastSuccessfulSend": "2024-01-15T10:30:00.0000000Z",
  "LastEventId": 12345
}
```

Questo file permette al servizio di:
- ? Riprendere da dove si era fermato dopo un reboot
- ? Tracciare la durata totale del deployment
- ? Evitare invii duplicati

---

## Deployment con Intune

### 1. Crea pacchetto Win32

```powershell
# Prepara cartella con tutti i file
New-Item -Path "C:\Temp\NimbusServicePackage" -ItemType Directory

# Copia file servizio
Copy-Item -Path "publish\service\*" -Destination "C:\Temp\NimbusServicePackage" -Recurse

# Copia script installazione
Copy-Item -Path "Install-DotNetService.ps1" -Destination "C:\Temp\NimbusServicePackage"
Copy-Item -Path "Uninstall-DotNetService.ps1" -Destination "C:\Temp\NimbusServicePackage"

# Crea wrapper script
@'
param($ApiEndpoint, $ApiKey)
$ServiceExe = Join-Path $PSScriptRoot "Nimbus.Autopilot.TelemetryService.exe"
& "$PSScriptRoot\Install-DotNetService.ps1" -ApiEndpoint $ApiEndpoint -ApiKey $ApiKey -ServiceExecutable $ServiceExe
'@ | Set-Content "C:\Temp\NimbusServicePackage\Install.ps1"

# Usa Microsoft Win32 Content Prep Tool
IntuneWinAppUtil.exe -c "C:\Temp\NimbusServicePackage" -s "Install.ps1" -o "C:\Temp\IntunePackages"
```

### 2. Configura in Intune

**Install command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File Install.ps1 -ApiEndpoint "https://api.yourdomain.com" -ApiKey "your_api_key"
```

**Uninstall command:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File Uninstall-DotNetService.ps1
```

**Detection rule:**
- **Type**: Registry
- **Key path**: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NimbusAutopilotTelemetry`
- **Detection method**: Key exists

---

## Troubleshooting

### Il servizio non si avvia

**Verifica:**
```powershell
# Check Event Log per errori
Get-EventLog -LogName Application -Source "Nimbus Autopilot Telemetry" -Newest 10 -EntryType Error

# Verifica file configurazione
Test-Path "C:\Program Files\Nimbus\AutopilotService\appsettings.json"

# Verifica .NET Framework 4.8
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" | Select-Object Release, Version
```

**Release number per .NET 4.8:**
- 528040 o superiore = .NET 4.8 installato

### Telemetria non inviata

```powershell
# Test connettività API
Invoke-RestMethod -Uri "https://your-api-endpoint.com/api/health"

# Verifica API key
$headers = @{ "X-API-Key" = "your_key" }
Invoke-RestMethod -Uri "https://your-api-endpoint.com/api/clients" -Headers $headers

# Check logs per errori HTTP
Get-EventLog -LogName Application -Source "Nimbus Autopilot Telemetry" | 
    Where-Object { $_.Message -like "*Failed to send*" }
```

### Esecuzione in Debug Mode

Per test locali:

```powershell
# Run come console application (non come servizio)
cd "C:\Program Files\Nimbus\AutopilotService"
.\Nimbus.Autopilot.TelemetryService.exe
```

Il servizio girerà in modalità console e mostrerà i log direttamente.

---

## Uninstallazione

### Script PowerShell

```powershell
.\Uninstall-DotNetService.ps1
```

### Manuale

```powershell
# Stop e rimuovi servizio
Stop-Service -Name NimbusAutopilotTelemetry
sc.exe delete NimbusAutopilotTelemetry

# Rimuovi Event Log source
[System.Diagnostics.EventLog]::DeleteEventSource("Nimbus Autopilot Telemetry")

# Rimuovi file
Remove-Item "C:\Program Files\Nimbus\AutopilotService" -Recurse -Force
Remove-Item "$env:ProgramData\Nimbus" -Recurse -Force
```

---

## Architettura Tecnica

### Componenti

```
TelemetryWorker (BackgroundService)
    ??? AutopilotTelemetryCollector
    ?   ??? Registry queries (ESP status)
    ?   ??? WMI queries (BIOS info)
    ?   ??? Phase detection logic
    ??? TelemetryApiClient
    ?   ??? HTTP client
  ?   ??? Retry logic
    ?   ??? JSON serialization
    ??? StateManager
        ??? JSON file I/O
        ??? State persistence
```

### Flusso di Esecuzione

```
1. Service starts (ExecuteAsync)
2. Load state from disk
3. Enter main loop:
   a. Collect telemetry data
   b. Check if should send
   c. Send to API with retry
   d. Save state
   e. Wait interval
   f. Send heartbeat every 5 min
4. On completion: enter maintenance mode
5. On stop: graceful shutdown
```

---

## Sviluppo

### Requisiti per Build

- **Visual Studio 2022** (o VS Code con C# extension)
- **.NET SDK 8.0** (per build tools, anche se target è .NET 4.8)
- **.NET Framework 4.8 Developer Pack**

### Debug in Visual Studio

1. Apri soluzione in Visual Studio
2. Imposta `TelemetryWorker` come startup project
3. F5 per debug
4. Il servizio girerà in modalità console

### Test Unitari

```powershell
# Aggiungi progetto test
dotnet new xunit -n Nimbus.Autopilot.TelemetryService.Tests
dotnet add reference ..\Nimbus.Autopilot.TelemetryService\

# Run tests
dotnet test
```

---

## Best Practices Aziendali

### Sicurezza

1. **Non hardcodare API key** - usa Azure Key Vault o Windows Credential Manager
2. **Usa HTTPS** per tutti gli endpoint API
3. **Limita permessi** - il servizio gira come LOCAL SYSTEM
4. **Audit logging** - monitora Event Log regolarmente

### Monitoraggio

1. **SCOM/Monitoring tool** - monitora Event Log errors
2. **API monitoring** - traccia ricezione telemetria lato server
3. **Heartbeat alerts** - alert se nessun heartbeat per >15 min

### Deployment

1. **Test in UAT** prima di production
2. **Gradual rollout** - pilot group ? production
3. **Rollback plan** - mantieni versione precedente disponibile
4. **Documentazione** - mantieni configurazioni documentate

---

## FAQ

**Q: Funziona con Windows 10 versione 1809?**  
A: No, richiede Windows 10 1903+ per .NET Framework 4.8

**Q: Posso usare .NET Core invece di .NET Framework?**  
A: Sì, ma richiede .NET Runtime installato sul client. .NET Framework 4.8 è già presente.

**Q: Il servizio supporta proxy?**  
A: Sì, usa le impostazioni proxy di sistema di Windows.

**Q: Posso cambiare l'API endpoint dopo l'installazione?**  
A: Sì, modifica `appsettings.json` e riavvia il servizio.

**Q: Come aggiorno il servizio a una nuova versione?**  
A: Stop service ? sovrascrivi file ? start service (lo stato è preservato).

---

## Supporto

- **Logs**: Event Viewer ? Application ? "Nimbus Autopilot Telemetry"
- **State**: `C:\ProgramData\Nimbus\telemetry-state.json`
- **Config**: `C:\Program Files\Nimbus\AutopilotService\appsettings.json`

---

## License

Stesso del progetto principale Nimbus.Autopilot

---

## Change Log

### Version 1.0.0
- Initial release
- .NET Framework 4.8 Windows Service
- Event Log integration
- State persistence
- Retry logic with exponential backoff
- Heartbeat support
- Maintenance mode
