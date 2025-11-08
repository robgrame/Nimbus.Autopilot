# Database Schema

## Overview
This directory contains the database schema for the Nimbus Autopilot telemetry system.

## Database Structure

### Tables

#### clients
Stores information about enrolled devices.
- `client_id`: Unique identifier for each client device (Primary Key)
- `device_name`: Friendly name of the device
- `enrolled_at`: Timestamp when device enrolled in Autopilot
- `last_seen`: Timestamp of last telemetry event
- `deployment_profile`: Name of the Autopilot deployment profile
- `status`: Current status (active, completed, failed)
- `created_at`, `updated_at`: Audit timestamps

#### deployment_phases
Defines the various phases of Autopilot deployment.
- `phase_id`: Auto-incrementing primary key
- `phase_name`: Name of the deployment phase
- `phase_order`: Sequential order of phases
- `description`: Description of the phase

#### telemetry_events
Stores telemetry data sent from client devices.
- `event_id`: Auto-incrementing primary key
- `client_id`: Reference to clients table
- `phase_id`: Reference to deployment_phases table
- `event_type`: Type of event (progress, error, completion, etc.)
- `event_timestamp`: When the event occurred on the client
- `progress_percentage`: Progress percentage (0-100)
- `status`: Event status (in_progress, completed, failed)
- `duration_seconds`: Time spent in current phase
- `error_message`: Error details if applicable
- `metadata`: Additional JSON data
- `created_at`: When record was inserted

### Views

#### v_deployment_progress
Provides a consolidated view of current deployment progress for all clients.

### Functions & Triggers

#### update_client_last_seen()
Automatically updates the `last_seen` timestamp on the clients table when new telemetry events are inserted.

## Setup

### PostgreSQL Setup

1. Install PostgreSQL:
```bash
# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib

# macOS
brew install postgresql
```

2. Create database and user:
```bash
sudo -u postgres psql
CREATE DATABASE nimbus_autopilot;
CREATE USER nimbus_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE nimbus_autopilot TO nimbus_user;
\q
```

3. Initialize schema:
```bash
psql -U nimbus_user -d nimbus_autopilot -f schema.sql
```

### Alternative: Docker Setup

```bash
docker run --name nimbus-postgres \
  -e POSTGRES_DB=nimbus_autopilot \
  -e POSTGRES_USER=nimbus_user \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  -d postgres:15

# Wait for container to be ready
sleep 5

# Initialize schema
docker exec -i nimbus-postgres psql -U nimbus_user -d nimbus_autopilot < schema.sql
```

## Environment Variables

The API service expects the following environment variables:
- `DB_HOST`: Database host (default: localhost)
- `DB_PORT`: Database port (default: 5432)
- `DB_NAME`: Database name (default: nimbus_autopilot)
- `DB_USER`: Database user
- `DB_PASSWORD`: Database password
