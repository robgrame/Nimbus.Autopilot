# Migration Guide: Python/PostgreSQL to .NET/SQL Server

This guide helps you migrate your existing Nimbus Autopilot deployment from the Python/Flask + PostgreSQL stack to the .NET/ASP.NET Core + SQL Server stack.

## Why Migrate?

The .NET stack offers several advantages for Microsoft-centric environments:

1. **Better Windows Integration**: Native Windows support and IIS deployment
2. **Performance**: Compiled code and efficient async operations
3. **Enterprise Support**: Microsoft backing and long-term support
4. **SQL Server Integration**: Optimized for SQL Server and Azure SQL
5. **Unified Microsoft Stack**: Consistent with other Microsoft technologies

## Prerequisites

Before starting the migration:

- [ ] .NET 8.0 SDK installed
- [ ] SQL Server 2019+ installed (or SQL Server Express/Azure SQL)
- [ ] Backup of existing PostgreSQL database
- [ ] API endpoint documented
- [ ] Current API key saved

## Migration Steps

### Step 1: Set Up SQL Server Database

#### Option A: Install SQL Server Locally

1. Download SQL Server 2019 Express (free) from Microsoft
2. Install with default settings
3. Note the connection details

#### Option B: Use SQL Server in Docker

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong@Passw0rd" \
   -p 1433:1433 --name nimbus-sqlserver \
   -d mcr.microsoft.com/mssql/server:2022-latest
```

#### Option C: Use Azure SQL Database

1. Create an Azure SQL Database
2. Note the connection string
3. Configure firewall rules

### Step 2: Create the Database Schema

```bash
# Connect to SQL Server
sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd'

# Create database
CREATE DATABASE nimbus_autopilot;
GO

# Exit and apply schema
\q

# Apply the schema
sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' \
   -d nimbus_autopilot -i database-sqlserver/schema.sql
```

### Step 3: Migrate Data (Optional)

If you need to migrate existing data from PostgreSQL to SQL Server:

#### Export Data from PostgreSQL

```bash
# Export clients
psql -U nimbus_user -d nimbus_autopilot -c "\COPY clients TO 'clients.csv' CSV HEADER"

# Export deployment_phases
psql -U nimbus_user -d nimbus_autopilot -c "\COPY deployment_phases TO 'phases.csv' CSV HEADER"

# Export telemetry_events
psql -U nimbus_user -d nimbus_autopilot -c "\COPY telemetry_events TO 'events.csv' CSV HEADER"
```

#### Import Data to SQL Server

```bash
# Use bcp utility or SQL Server Import Wizard
bcp nimbus_autopilot.dbo.clients in clients.csv -S localhost -U sa -P 'YourStrong@Passw0rd' -c -t,

# Or use SQL Server Management Studio's Import Data wizard
```

**Note**: You may need to adjust data formats, especially for:
- Date/time fields (PostgreSQL TIMESTAMP vs SQL Server DATETIME2)
- JSON fields (JSONB vs NVARCHAR(MAX))
- Serial/Identity columns

### Step 4: Deploy .NET API

#### Development Deployment

```bash
cd api-dotnet/Nimbus.Autopilot.Api

# Update connection string in appsettings.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=nimbus_autopilot;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;"
  },
  "ApiKey": "your_existing_api_key"
}

# Run the API
dotnet run
```

#### Production Deployment with Docker

```bash
# Build Docker image
cd api-dotnet
docker build -t nimbus-api-dotnet .

# Run container
docker run -d \
  -p 5000:5000 \
  -e ConnectionStrings__DefaultConnection="Server=host.docker.internal;Database=nimbus_autopilot;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;" \
  -e ApiKey="your_existing_api_key" \
  --name nimbus-api-dotnet \
  nimbus-api-dotnet
```

#### IIS Deployment (Windows Server)

1. Publish the application:
   ```bash
   dotnet publish -c Release -o ./publish
   ```

2. Install .NET 8.0 Hosting Bundle on IIS server
3. Create new IIS Application Pool (.NET CLR Version: No Managed Code)
4. Create new Website pointing to publish folder
5. Update `appsettings.json` with production settings
6. Configure SSL certificate

### Step 5: Update Dashboard Configuration

The React dashboard works with both APIs without code changes. Just update the environment:

```bash
cd dashboard

# Update .env file
REACT_APP_API_URL=http://localhost:5000
REACT_APP_API_KEY=your_existing_api_key

# Rebuild if needed
npm run build
```

### Step 6: Test the New API

#### Test Health Endpoint

```bash
curl http://localhost:5000/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### Test Telemetry Ingestion

```bash
curl -X POST http://localhost:5000/api/telemetry \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{
    "client_id": "TEST-001",
    "device_name": "TEST-DEVICE",
    "event_type": "progress",
    "event_timestamp": "2024-01-15T10:30:00Z",
    "progress_percentage": 50
  }'
```

#### Test Client Query

```bash
curl http://localhost:5000/api/clients \
  -H "X-API-Key: your_api_key"
```

### Step 7: Update Client Devices (No Changes Needed!)

The PowerShell client works with both APIs without modification. Just ensure:

1. API endpoint URL points to new .NET API
2. API key is correct
3. Network connectivity is working

### Step 8: Gradual Migration (Recommended)

Run both APIs in parallel during migration:

1. Keep Python API running on port 5001
2. Start .NET API on port 5000
3. Point new devices to .NET API
4. Monitor both systems
5. Gradually move existing devices
6. Decommission Python API after validation

### Step 9: Decommission Python Stack

Once confident in the .NET stack:

```bash
# Stop Python API container
docker stop nimbus-api-python

# Stop PostgreSQL container (after data migration)
docker stop nimbus-postgres

# Remove old containers (optional)
docker rm nimbus-api-python nimbus-postgres
```

## Troubleshooting

### Connection Issues

**Problem**: Cannot connect to SQL Server

**Solutions**:
- Enable TCP/IP in SQL Server Configuration Manager
- Check firewall allows port 1433
- Verify SQL Server is running: `systemctl status mssql-server` (Linux) or Services (Windows)
- For Docker, use `host.docker.internal` instead of `localhost`

### Authentication Issues

**Problem**: API returns 401 Unauthorized

**Solutions**:
- Verify API key in configuration matches client
- Check `X-API-Key` header is being sent
- Review API logs for authentication errors

### Data Type Mismatches

**Problem**: Errors when migrating data

**Solutions**:
- Convert PostgreSQL timestamps to SQL Server DATETIME2 format
- Parse JSONB to JSON string
- Adjust `SERIAL` to `IDENTITY` columns (skip during import)

### Performance Issues

**Problem**: Slower than Python API

**Solutions**:
- Ensure indexes are created (check schema.sql)
- Monitor SQL Server query plans
- Enable connection pooling
- Consider using Azure SQL Database for better scaling

## Rollback Plan

If you need to rollback to Python:

1. Keep Python API and PostgreSQL running during transition
2. Document all configuration changes
3. Keep database backups
4. Test rollback procedure in staging first

## Support

For issues during migration:

1. Check logs in .NET API: `dotnet run --verbosity detailed`
2. Review SQL Server error logs
3. Open GitHub issue with migration details
4. Consult .NET API README and SQL Server documentation

## Post-Migration Checklist

- [ ] All client devices reporting to new API
- [ ] Dashboard shows current data
- [ ] API performance is acceptable
- [ ] Database backups configured
- [ ] Monitoring and alerts set up
- [ ] Documentation updated
- [ ] Team trained on new stack
- [ ] Old infrastructure decommissioned
