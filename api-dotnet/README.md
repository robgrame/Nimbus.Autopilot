# Nimbus Autopilot API (.NET)

ASP.NET Core 8.0 Web API for the Nimbus Autopilot telemetry system.

## Prerequisites

- .NET 8.0 SDK or later
- SQL Server 2019+ (or SQL Server Express/Docker container)

## Setup

### 1. Install Dependencies

The project dependencies are restored automatically when building, but you can manually restore them:

```bash
dotnet restore
```

### 2. Configure Database

Update the connection string in `appsettings.json` or use environment variables:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=nimbus_autopilot;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;"
  }
}
```

### 3. Create Database Schema

Run the SQL Server schema script from the `database-sqlserver` directory:

```bash
# Using sqlcmd
sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -Q "CREATE DATABASE nimbus_autopilot;"
sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -d nimbus_autopilot -i ../database-sqlserver/schema.sql
```

Alternatively, you can use Entity Framework migrations:

```bash
# Install EF Core tools (if not already installed)
dotnet tool install --global dotnet-ef

# Create initial migration
dotnet ef migrations add InitialCreate

# Apply migration to database
dotnet ef database update
```

### 4. Configure API Key

Set your API key in `appsettings.json` or via environment variable:

```json
{
  "ApiKey": "your_secure_api_key_here"
}
```

Or using environment variable:
```bash
export ApiKey="your_secure_api_key_here"
```

### 5. Run the API

```bash
dotnet run
```

The API will start on `http://localhost:5000` by default.

## Development

### Build

```bash
dotnet build
```

### Run in Development Mode

```bash
dotnet run --environment Development
```

The API includes Swagger/OpenAPI documentation available at `http://localhost:5000/swagger` when running in Development mode.

### Run Tests

```bash
dotnet test
```

## API Endpoints

### Web UI (NEW - SignalR Real-time Dashboard)
```
GET /                    # Home page
GET /Home/Dashboard      # Real-time telemetry dashboard
```

The new SignalR-powered dashboard provides real-time monitoring of telemetry events. See [SIGNALR_DASHBOARD.md](./SIGNALR_DASHBOARD.md) for detailed documentation.

**SignalR Hub**:
```
WebSocket /hubs/telemetry
```
Automatically broadcasts telemetry updates to all connected clients.

### Health Check
```
GET /api/health
```
No authentication required. Returns the health status of the API and database.

### Telemetry Ingestion
```
POST /api/telemetry
Headers: X-API-Key: your_api_key
Content-Type: application/json
```

Request body:
```json
{
  "clientId": "DEVICE-12345",
  "deviceName": "LAPTOP-ABC",
  "deploymentProfile": "Standard",
  "phaseName": "Device Setup",
  "eventType": "progress",
  "eventTimestamp": "2024-01-15T10:30:00Z",
  "progressPercentage": 45,
  "status": "in_progress",
  "durationSeconds": 120,
  "errorMessage": null,
  "metadata": {}
}
```

### Query Clients
```
GET /api/clients?status=active&limit=100&offset=0
Headers: X-API-Key: your_api_key
```

### Get Client Details
```
GET /api/clients/{clientId}
Headers: X-API-Key: your_api_key
```

### Query Telemetry
```
GET /api/telemetry?client_id=DEVICE-001&limit=100&offset=0
Headers: X-API-Key: your_api_key
```

Query parameters:
- `client_id`: Filter by client ID
- `phase_name`: Filter by deployment phase
- `status`: Filter by event status
- `from_date`: Start date (ISO 8601)
- `to_date`: End date (ISO 8601)
- `limit`: Results per page (default: 100)
- `offset`: Pagination offset (default: 0)

### Statistics
```
GET /api/stats
Headers: X-API-Key: your_api_key
```

### Deployment Phases
```
GET /api/deployment-phases
Headers: X-API-Key: your_api_key
```

## Docker Deployment

### Build Docker Image

```bash
docker build -t nimbus-api-dotnet .
```

### Run in Docker

```bash
docker run -d \
  -p 5000:5000 \
  -e ConnectionStrings__DefaultConnection="Server=host.docker.internal;Database=nimbus_autopilot;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;" \
  -e ApiKey="your_api_key" \
  --name nimbus-api \
  nimbus-api-dotnet
```

## Configuration

### Environment Variables

The application supports configuration via environment variables:

- `ConnectionStrings__DefaultConnection`: Database connection string
- `ApiKey`: API key for authentication
- `ASPNETCORE_ENVIRONMENT`: Environment (Development, Staging, Production)
- `ASPNETCORE_URLS`: URLs to listen on (default: http://+:5000)
- `Logging__LogLevel__Default`: Default log level

### appsettings.json

You can also configure the application via `appsettings.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=nimbus_autopilot;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;"
  },
  "ApiKey": "change_me_in_production"
}
```

## Security

### API Key Authentication

All endpoints except `/api/health` and Swagger documentation require API key authentication via the `X-API-Key` header.

### HTTPS

In production, always use HTTPS. Configure your reverse proxy (IIS, nginx, Apache) or Azure App Service to handle SSL/TLS termination.

### SQL Injection Protection

The application uses Entity Framework Core with parameterized queries, which provides protection against SQL injection attacks.

## Project Structure

```
Nimbus.Autopilot.Api/
├── Controllers/          # API and MVC controllers
│   ├── HealthController.cs
│   ├── TelemetryController.cs
│   ├── ClientsController.cs
│   ├── StatsController.cs
│   └── HomeController.cs (NEW - MVC)
├── Data/                 # Database context
│   └── NimbusDbContext.cs
├── Hubs/                 # SignalR hubs (NEW)
│   └── TelemetryHub.cs
├── Middleware/           # Custom middleware
│   └── ApiKeyAuthenticationMiddleware.cs
├── Models/               # Data models and DTOs
│   ├── Client.cs
│   ├── DeploymentPhase.cs
│   ├── TelemetryEvent.cs
│   └── Dtos.cs
├── Views/                # Razor views (NEW)
│   ├── Home/
│   │   ├── Index.cshtml
│   │   └── Dashboard.cshtml
│   ├── Shared/
│   │   └── _Layout.cshtml
│   ├── _ViewStart.cshtml
│   └── _ViewImports.cshtml
├── wwwroot/              # Static files (NEW)
├── Program.cs            # Application entry point
├── appsettings.json      # Configuration
└── Nimbus.Autopilot.Api.csproj
```

## Migration from Python/Flask

This .NET implementation replaces the Python Flask API with the following changes:

1. **Technology Stack**: 
   - Python/Flask → ASP.NET Core 8.0
   - PostgreSQL → SQL Server
   - psycopg2 → Entity Framework Core with SQL Server provider

2. **API Compatibility**: 
   - All endpoints maintain the same URL structure
   - Request/response formats are identical
   - API key authentication works the same way

3. **Performance**: 
   - Compiled .NET code typically offers better performance
   - Entity Framework provides efficient database operations
   - Built-in async/await support for scalability

4. **Deployment**: 
   - Single compiled binary (no interpreter needed)
   - Native Windows and Linux support
   - IIS integration for Windows servers

## Troubleshooting

### Database Connection Issues

1. Verify SQL Server is running
2. Check connection string is correct
3. Ensure firewall allows connections on port 1433
4. For Docker, use `host.docker.internal` instead of `localhost`

### API Key Authentication

1. Ensure `X-API-Key` header is included in requests
2. Verify the API key matches the configured value
3. Check logs for authentication failures

### Entity Framework Issues

```bash
# Clear EF migrations
rm -rf Migrations/

# Recreate migrations
dotnet ef migrations add InitialCreate
dotnet ef database update
```

## License

See main repository LICENSE file.
