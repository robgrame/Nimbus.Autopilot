# Nimbus.Autopilot Visual Studio Solution

## Solution Structure

```
Nimbus.Autopilot.sln
?
??? ?? Solution Items (Documentation & Configuration)
?   ??? README.md
?   ??? COMPARISON.md
?   ??? .gitignore
?   ??? LICENSE
?   ??? docker-compose.yml
?   ??? docker-compose-dotnet.yml
?
??? ?? api-dotnet (Backend API)
?   ??? ?? Nimbus.Autopilot.Api (.NET 8.0 Web API)
?       ??? Controllers/
?       ??? Data/
?       ??? Hubs/ (SignalR)
?       ??? Middleware/
?       ??? Models/
?       ??? Views/
?
??? ?? service-dotnet (Windows Service)
?   ??? ?? Nimbus.Autopilot.TelemetryService (.NET Framework 4.8)
?   ?   ??? Models/
?   ? ??? Services/
?   ?   ??? Program.cs
? ?   ??? TelemetryWorker.cs
?   ?   ??? appsettings.json
?   ?
?   ??? ?? service-scripts
?   ??? README.md
?       ??? Install-DotNetService.ps1
?     ??? Uninstall-DotNetService.ps1
?
??? ?? client (PowerShell Solutions & Docs)
    ??? Documentation:
    ?   ??? README.md
    ?   ??? QUICKSTART.md
  ?   ??? SERVICE-DEPLOYMENT.md
    ?   ??? INTUNE-DEPLOYMENT.md
    ?   ??? DECISION-GUIDE.md
    ?   ??? SOLUTION-OVERVIEW.md
    ?
    ??? Scripts:
        ??? Send-AutopilotTelemetry.ps1
        ??? Send-AutopilotTelemetry-Service.ps1
        ??? Install-TelemetryService.ps1
  ??? Install-TelemetryService-NoNSSM.ps1
        ??? Install-TelemetryService-TaskSchedulerOnly.ps1
        ??? Uninstall-TelemetryService.ps1
```

## Projects

### ?? Nimbus.Autopilot.Api
**Type:** ASP.NET Core 8.0 Web API  
**Framework:** .NET 8.0  
**Purpose:** Backend API for receiving and storing telemetry data  
**Database:** SQL Server  
**Features:**
- RESTful API endpoints
- SignalR real-time updates
- Entity Framework Core
- Swagger/OpenAPI documentation

**Build:**
```bash
cd api-dotnet\Nimbus.Autopilot.Api
dotnet build
dotnet run
```

**Access:** http://localhost:5000

---

### ?? Nimbus.Autopilot.TelemetryService
**Type:** Windows Service  
**Framework:** .NET Framework 4.8  
**Purpose:** Client-side telemetry collection service  
**Features:**
- Background service (BackgroundService)
- Registry/WMI queries for Autopilot status
- HTTP client with retry logic
- State persistence across reboots
- Event Log integration

**Build:**
```bash
cd service-dotnet\Nimbus.Autopilot.TelemetryService
dotnet publish -c Release -o ..\..\publish\service
```

**Install:**
```powershell
.\service-dotnet\Install-DotNetService.ps1 `
    -ApiEndpoint "http://localhost:5000" `
    -ApiKey "your_api_key" `
-ServiceExecutable "C:\path\to\publish\service\Nimbus.Autopilot.TelemetryService.exe"
```

---

## Build All Projects

### Using Visual Studio
1. Open `Nimbus.Autopilot.sln` in Visual Studio 2022
2. Build ? Build Solution (Ctrl+Shift+B)
3. All projects will be built

### Using .NET CLI
```bash
# From solution root
dotnet build

# Or build specific project
dotnet build api-dotnet\Nimbus.Autopilot.Api\Nimbus.Autopilot.Api.csproj
dotnet build service-dotnet\Nimbus.Autopilot.TelemetryService\Nimbus.Autopilot.TelemetryService.csproj
```

### Configuration Profiles
- **Debug**: Development builds with symbols
- **Release**: Optimized production builds

---

## Development Workflow

### 1. Start Backend API
```bash
cd api-dotnet\Nimbus.Autopilot.Api
dotnet run
```

### 2. Build Windows Service
```bash
cd service-dotnet\Nimbus.Autopilot.TelemetryService
dotnet publish -c Release -o ..\..\publish\service
```

### 3. Test Service Locally
```bash
# Run as console app (for debugging)
cd publish\service
.\Nimbus.Autopilot.TelemetryService.exe
```

### 4. Install Service
```powershell
.\service-dotnet\Install-DotNetService.ps1 `
    -ApiEndpoint "http://localhost:5000" `
    -ApiKey "test_key"
```

---

## Running Tests

### API Tests
```bash
cd api-dotnet\Nimbus.Autopilot.Api
dotnet test
```

### Service Tests
```bash
cd service-dotnet\Nimbus.Autopilot.TelemetryService
dotnet test
```

---

## Publishing for Production

### Backend API
```bash
cd api-dotnet\Nimbus.Autopilot.Api
dotnet publish -c Release -r win-x64 --self-contained false
```

### Windows Service
```bash
cd service-dotnet\Nimbus.Autopilot.TelemetryService
dotnet publish -c Release -o ..\..\dist\service
```

### Docker Deployment
```bash
# Build and run with Docker Compose
docker-compose -f docker-compose-dotnet.yml up -d
```

---

## Dependencies

### Nimbus.Autopilot.Api
- Microsoft.EntityFrameworkCore.SqlServer
- Microsoft.AspNetCore.SignalR
- Newtonsoft.Json
- Swashbuckle.AspNetCore

### Nimbus.Autopilot.TelemetryService
- Microsoft.Extensions.Hosting
- Microsoft.Extensions.Hosting.WindowsServices
- Newtonsoft.Json
- System.Management

---

## Solution Configuration

### Target Frameworks
- **API**: .NET 8.0 (modern, cross-platform)
- **Service**: .NET Framework 4.8 (Windows-native, no runtime required on Win10/11)

### Why Two Different Frameworks?
- **API (.NET 8.0)**: Modern framework, better performance, SignalR support
- **Service (.NET 4.8)**: Already installed on Windows 10/11, zero deployment dependencies

---

## Quick Commands

```bash
# Build everything
dotnet build

# Restore NuGet packages
dotnet restore

# Clean build artifacts
dotnet clean

# Run API
dotnet run --project api-dotnet\Nimbus.Autopilot.Api\Nimbus.Autopilot.Api.csproj

# Publish service
dotnet publish service-dotnet\Nimbus.Autopilot.TelemetryService\Nimbus.Autopilot.TelemetryService.csproj -c Release
```

---

## Documentation

All documentation is accessible from Solution Explorer ? Solution Items folders:

- **Root Level**: Architecture comparison, Docker setup
- **Client Folder**: PowerShell deployment guides
- **Service-Scripts Folder**: .NET Service installation

---

## Git Integration

The solution is configured with:
- `.gitignore` - Excludes build artifacts, packages, etc.
- Branch: `main`
- Remote: https://github.com/robgrame/Nimbus.Autopilot

### Commit Changes
```bash
git add .
git commit -m "Your commit message"
git push origin main
```

---

## Support

For issues or questions:
- Check documentation in `client/` folder
- Review `COMPARISON.md` for solution options
- See individual project README files

---

## License

See [LICENSE](LICENSE) file for details.
