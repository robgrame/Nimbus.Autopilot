# API Documentation

## Overview

The Nimbus Autopilot API provides RESTful endpoints for ingesting telemetry data from client devices and querying deployment information for the dashboard.

**Base URL:** `http://localhost:5000` (development)

**Authentication:** API Key via `X-API-Key` header

## Authentication

All endpoints (except `/api/health`) require authentication via API key.

**Header:**
```
X-API-Key: your_api_key_here
```

**Example:**
```bash
curl -H "X-API-Key: your_api_key" http://localhost:5000/api/clients
```

## Endpoints

### Health Check

Check API and database connectivity.

**Endpoint:** `GET /api/health`

**Authentication:** Not required

**Response:**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Status Codes:**
- `200 OK` - Service is healthy
- `503 Service Unavailable` - Service is unhealthy

---

### Ingest Telemetry

Submit telemetry data from client devices.

**Endpoint:** `POST /api/telemetry`

**Authentication:** Required

**Request Body:**
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

**Required Fields:**
- `client_id` (string)
- `event_type` (string)
- `event_timestamp` (ISO 8601 datetime)

**Optional Fields:**
- `device_name` (string)
- `deployment_profile` (string)
- `phase_name` (string) - Must match existing deployment phase
- `progress_percentage` (integer, 0-100)
- `status` (string)
- `duration_seconds` (integer)
- `error_message` (string)
- `metadata` (object)

**Response:**
```json
{
  "success": true,
  "message": "Telemetry data received",
  "event_id": 12345
}
```

**Status Codes:**
- `201 Created` - Telemetry received successfully
- `400 Bad Request` - Missing required fields or validation error
- `401 Unauthorized` - Invalid or missing API key
- `500 Internal Server Error` - Server error

**Example:**
```bash
curl -X POST http://localhost:5000/api/telemetry \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{
    "client_id": "TEST-001",
    "device_name": "TEST-DEVICE",
    "event_type": "progress",
    "event_timestamp": "2024-01-15T10:30:00Z",
    "phase_name": "Device Setup",
    "progress_percentage": 50,
    "status": "in_progress"
  }'
```

---

### List Clients

Retrieve a list of all enrolled client devices.

**Endpoint:** `GET /api/clients`

**Authentication:** Required

**Query Parameters:**
- `status` (string, optional) - Filter by client status
- `limit` (integer, optional) - Number of results (default: 100, max: 100)
- `offset` (integer, optional) - Pagination offset (default: 0)

**Response:**
```json
{
  "clients": [
    {
      "client_id": "DEVICE-12345",
      "device_name": "LAPTOP-ABC",
      "enrolled_at": "2024-01-15T09:00:00.000Z",
      "last_seen": "2024-01-15T10:30:00.000Z",
      "deployment_profile": "Standard",
      "status": "active",
      "created_at": "2024-01-15T09:00:00.000Z",
      "updated_at": "2024-01-15T10:30:00.000Z"
    }
  ],
  "total": 150,
  "limit": 100,
  "offset": 0
}
```

**Status Codes:**
- `200 OK` - Success
- `401 Unauthorized` - Invalid or missing API key
- `500 Internal Server Error` - Server error

**Example:**
```bash
# Get all active clients
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/clients?status=active&limit=50"
```

---

### Get Client Details

Retrieve detailed information for a specific client including all telemetry events.

**Endpoint:** `GET /api/clients/{client_id}`

**Authentication:** Required

**Path Parameters:**
- `client_id` (string) - Unique client identifier

**Response:**
```json
{
  "client": {
    "client_id": "DEVICE-12345",
    "device_name": "LAPTOP-ABC",
    "enrolled_at": "2024-01-15T09:00:00.000Z",
    "last_seen": "2024-01-15T10:30:00.000Z",
    "deployment_profile": "Standard",
    "status": "active",
    "created_at": "2024-01-15T09:00:00.000Z",
    "updated_at": "2024-01-15T10:30:00.000Z"
  },
  "events": [
    {
      "event_id": 12345,
      "client_id": "DEVICE-12345",
      "phase_id": 2,
      "phase_name": "Device Setup",
      "phase_order": 2,
      "event_type": "progress",
      "event_timestamp": "2024-01-15T10:30:00.000Z",
      "progress_percentage": 45,
      "status": "in_progress",
      "duration_seconds": 120,
      "error_message": null,
      "metadata": {},
      "created_at": "2024-01-15T10:30:05.000Z"
    }
  ]
}
```

**Status Codes:**
- `200 OK` - Success
- `401 Unauthorized` - Invalid or missing API key
- `404 Not Found` - Client not found
- `500 Internal Server Error` - Server error

**Example:**
```bash
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/clients/DEVICE-12345"
```

---

### Query Telemetry Events

Query telemetry events with various filters.

**Endpoint:** `GET /api/telemetry`

**Authentication:** Required

**Query Parameters:**
- `client_id` (string, optional) - Filter by client ID
- `phase_name` (string, optional) - Filter by deployment phase
- `status` (string, optional) - Filter by event status
- `from_date` (ISO 8601, optional) - Start date/time
- `to_date` (ISO 8601, optional) - End date/time
- `limit` (integer, optional) - Number of results (default: 100, max: 100)
- `offset` (integer, optional) - Pagination offset (default: 0)

**Response:**
```json
{
  "events": [
    {
      "event_id": 12345,
      "client_id": "DEVICE-12345",
      "device_name": "LAPTOP-ABC",
      "phase_id": 2,
      "phase_name": "Device Setup",
      "phase_order": 2,
      "event_type": "progress",
      "event_timestamp": "2024-01-15T10:30:00.000Z",
      "progress_percentage": 45,
      "status": "in_progress",
      "duration_seconds": 120,
      "error_message": null,
      "metadata": {},
      "created_at": "2024-01-15T10:30:05.000Z"
    }
  ],
  "limit": 100,
  "offset": 0
}
```

**Status Codes:**
- `200 OK` - Success
- `401 Unauthorized` - Invalid or missing API key
- `500 Internal Server Error` - Server error

**Example:**
```bash
# Get all events for a specific client in a date range
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/telemetry?client_id=DEVICE-12345&from_date=2024-01-15T00:00:00Z&to_date=2024-01-15T23:59:59Z"
```

---

### Get Deployment Phases

Retrieve all available deployment phases.

**Endpoint:** `GET /api/deployment-phases`

**Authentication:** Required

**Response:**
```json
{
  "phases": [
    {
      "phase_id": 1,
      "phase_name": "Device Preparation",
      "phase_order": 1,
      "description": "Initial device setup and preparation",
      "created_at": "2024-01-15T00:00:00.000Z"
    },
    {
      "phase_id": 2,
      "phase_name": "Device Setup",
      "phase_order": 2,
      "description": "Core device configuration",
      "created_at": "2024-01-15T00:00:00.000Z"
    }
  ]
}
```

**Status Codes:**
- `200 OK` - Success
- `401 Unauthorized` - Invalid or missing API key
- `500 Internal Server Error` - Server error

**Example:**
```bash
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/deployment-phases"
```

---

### Get Statistics

Retrieve overall deployment statistics and metrics.

**Endpoint:** `GET /api/stats`

**Authentication:** Required

**Response:**
```json
{
  "total_clients": 150,
  "clients_by_status": [
    {
      "status": "active",
      "count": 45
    },
    {
      "status": "completed",
      "count": 100
    },
    {
      "status": "failed",
      "count": 5
    }
  ],
  "active_deployments": 12,
  "average_duration_seconds": 3600
}
```

**Status Codes:**
- `200 OK` - Success
- `401 Unauthorized` - Invalid or missing API key
- `500 Internal Server Error` - Server error

**Example:**
```bash
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/stats"
```

---

## Error Responses

All endpoints return consistent error responses:

```json
{
  "error": "Error Type",
  "message": "Detailed error message"
}
```

**Common Error Types:**
- `Unauthorized` - Invalid or missing API key
- `Bad Request` - Invalid request data
- `Not Found` - Resource not found
- `Internal Server Error` - Server error

## Rate Limiting

Currently, no rate limiting is implemented. Consider implementing rate limiting in production using:
- Nginx rate limiting
- API gateway
- Application-level rate limiting (e.g., Flask-Limiter)

## Versioning

The API is currently at version 1.0. Future versions will be indicated by URL path (e.g., `/api/v2/...`).

## CORS

CORS is enabled for all origins in development. In production, configure allowed origins via the `CORS_ORIGINS` environment variable.

## Pagination

Endpoints that return lists support pagination via `limit` and `offset` query parameters.

**Example:**
```bash
# Get first 50 clients
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/clients?limit=50&offset=0"

# Get next 50 clients
curl -H "X-API-Key: your_api_key" \
  "http://localhost:5000/api/clients?limit=50&offset=50"
```

## Best Practices

1. **Use HTTPS** in production
2. **Store API keys securely** - use environment variables
3. **Implement retry logic** with exponential backoff
4. **Validate data** before sending
5. **Handle errors gracefully**
6. **Monitor API usage**
7. **Keep credentials secure**
