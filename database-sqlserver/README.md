# Nimbus Autopilot Database - SQL Server

This directory contains the SQL Server database schema for the Nimbus Autopilot telemetry system.

## Setup

### Prerequisites

- SQL Server 2019 or later (Express, Standard, or Enterprise)
- SQL Server Management Studio (SSMS) or Azure Data Studio (optional)

### Installation

#### Option 1: Using SQL Server Management Studio (SSMS)

1. Connect to your SQL Server instance
2. Create a new database:
   ```sql
   CREATE DATABASE nimbus_autopilot;
   ```
3. Open the `schema.sql` file in SSMS
4. Execute the script against the `nimbus_autopilot` database

#### Option 2: Using sqlcmd

```bash
# Create the database
sqlcmd -S localhost -U sa -P 'YourPassword' -Q "CREATE DATABASE nimbus_autopilot;"

# Run the schema script
sqlcmd -S localhost -U sa -P 'YourPassword' -d nimbus_autopilot -i schema.sql
```

#### Option 3: Using Docker

```bash
# Run SQL Server in Docker
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong@Passw0rd" \
   -p 1433:1433 --name nimbus-sqlserver \
   -d mcr.microsoft.com/mssql/server:2022-latest

# Wait for SQL Server to start (about 30 seconds)
sleep 30

# Create database and apply schema
docker exec -i nimbus-sqlserver /opt/mssql-tools/bin/sqlcmd \
   -S localhost -U sa -P "YourStrong@Passw0rd" \
   -Q "CREATE DATABASE nimbus_autopilot;"

docker exec -i nimbus-sqlserver /opt/mssql-tools/bin/sqlcmd \
   -S localhost -U sa -P "YourStrong@Passw0rd" \
   -d nimbus_autopilot < schema.sql
```

### Connection String

Update your application's connection string to point to SQL Server:

```
Server=localhost;Database=nimbus_autopilot;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;
```

For production, use Windows Authentication or a dedicated service account:

```
Server=your-server;Database=nimbus_autopilot;Integrated Security=True;
```

## Schema Overview

### Tables

- **clients**: Stores client device information
- **deployment_phases**: Predefined deployment phases
- **telemetry_events**: Telemetry data from client devices

### Views

- **v_deployment_progress**: Current deployment status for all clients

### Triggers

- **trg_update_client_last_seen**: Automatically updates the `last_seen` timestamp when telemetry is received

## Differences from PostgreSQL

This SQL Server schema is converted from the PostgreSQL version with the following changes:

1. **Data Types**:
   - `VARCHAR` → `NVARCHAR` (for Unicode support)
   - `TIMESTAMP` → `DATETIME2`
   - `SERIAL` → `INT IDENTITY`
   - `JSONB` → `NVARCHAR(MAX)` (stored as JSON string)
   - `TEXT` → `NVARCHAR(MAX)`

2. **Functions**:
   - `CURRENT_TIMESTAMP` → `GETUTCDATE()`
   - `NOW()` → `GETUTCDATE()`
   - `EXTRACT(EPOCH FROM ...)` → `DATEDIFF(SECOND, ...)`
   - `INTERVAL '1 hour'` → `DATEADD(HOUR, -1, GETUTCDATE())`

3. **Triggers**:
   - SQL Server uses AFTER INSERT triggers instead of PostgreSQL's FOR EACH ROW triggers
   - Uses `inserted` pseudo-table instead of `NEW` record

4. **Constraints**:
   - Foreign key cascade delete syntax is the same
   - `ON DELETE SET NULL` is supported

## Maintenance

### Backup

```sql
BACKUP DATABASE nimbus_autopilot 
TO DISK = 'C:\Backups\nimbus_autopilot.bak' 
WITH FORMAT, NAME = 'Full Backup of nimbus_autopilot';
```

### Index Maintenance

```sql
-- Rebuild all indexes
ALTER INDEX ALL ON clients REBUILD;
ALTER INDEX ALL ON telemetry_events REBUILD;
ALTER INDEX ALL ON deployment_phases REBUILD;

-- Update statistics
UPDATE STATISTICS clients;
UPDATE STATISTICS telemetry_events;
UPDATE STATISTICS deployment_phases;
```

### Query Performance

Monitor long-running queries using SQL Server Profiler or Extended Events.

```sql
-- Find missing indexes
SELECT 
    migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    mid.statement,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10
ORDER BY improvement_measure DESC;
```
