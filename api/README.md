# Nimbus Autopilot API

REST API backend for the Nimbus Autopilot telemetry system.

## Features

- **Telemetry Ingestion**: Receive telemetry data from client devices
- **Data Querying**: Query client and telemetry data with flexible filters
- **Statistics**: Get deployment statistics and insights
- **Authentication**: API key-based authentication
- **Error Handling**: Comprehensive error handling and validation

## API Endpoints

### Health Check
```
GET /api/health
```
Check API and database connectivity status.

### Telemetry Ingestion
```
POST /api/telemetry
Headers: X-API-Key: your_api_key
```
Submit telemetry data from client devices.

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
  "metadata": {}
}
```

### Get Clients
```
GET /api/clients?status=active&limit=100&offset=0
Headers: X-API-Key: your_api_key
```
Retrieve list of all clients with optional filtering.

### Get Client Details
```
GET /api/clients/{client_id}
Headers: X-API-Key: your_api_key
```
Get detailed information for a specific client including all telemetry events.

### Query Telemetry
```
GET /api/telemetry?client_id=DEVICE-12345&phase_name=Device%20Setup&status=in_progress
Headers: X-API-Key: your_api_key
```
Query telemetry events with various filters.

**Query Parameters:**
- `client_id`: Filter by client ID
- `phase_name`: Filter by deployment phase
- `status`: Filter by event status
- `from_date`: Start date (ISO format)
- `to_date`: End date (ISO format)
- `limit`: Number of results (default: 100)
- `offset`: Pagination offset (default: 0)

### Get Deployment Phases
```
GET /api/deployment-phases
Headers: X-API-Key: your_api_key
```
Get all available deployment phases.

### Get Statistics
```
GET /api/stats
Headers: X-API-Key: your_api_key
```
Get overall deployment statistics and metrics.

## Setup

### Prerequisites
- Python 3.8+
- PostgreSQL 12+

### Installation

1. Install dependencies:
```bash
cd api
pip install -r requirements.txt
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your database credentials and API key
```

3. Initialize database:
```bash
cd ../database
psql -U nimbus_user -d nimbus_autopilot -f schema.sql
```

4. Run the API:
```bash
cd ../api
python app.py
```

The API will be available at `http://localhost:5000`.

### Production Deployment

Use Gunicorn for production:
```bash
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

## Security

- **API Key Authentication**: All endpoints (except `/api/health`) require a valid API key in the `X-API-Key` header
- **CORS**: Cross-Origin Resource Sharing is enabled for frontend access
- **Environment Variables**: Sensitive data stored in environment variables
- **SQL Injection Protection**: Using parameterized queries via psycopg2

## Testing

Example cURL commands:

```bash
# Health check
curl http://localhost:5000/api/health

# Submit telemetry
curl -X POST http://localhost:5000/api/telemetry \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d '{
    "client_id": "TEST-001",
    "device_name": "TEST-DEVICE",
    "deployment_profile": "Standard",
    "phase_name": "Device Setup",
    "event_type": "progress",
    "event_timestamp": "2024-01-15T10:30:00Z",
    "progress_percentage": 50,
    "status": "in_progress"
  }'

# Get clients
curl http://localhost:5000/api/clients \
  -H "X-API-Key: your_api_key"

# Get statistics
curl http://localhost:5000/api/stats \
  -H "X-API-Key: your_api_key"
```

## Error Handling

The API returns standard HTTP status codes:
- `200`: Success
- `201`: Created
- `400`: Bad Request
- `401`: Unauthorized
- `404`: Not Found
- `500`: Internal Server Error
- `503`: Service Unavailable

Error responses include a JSON body:
```json
{
  "error": "Error Type",
  "message": "Detailed error message"
}
```
