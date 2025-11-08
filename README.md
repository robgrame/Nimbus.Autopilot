# Nimbus.Autopilot

Enterprise-grade telemetry monitoring solution for Windows Autopilot deployments. Track and visualize device deployment progress through the Enrollment Status Page (ESP) in real-time.

## Overview

Nimbus.Autopilot provides a complete solution for monitoring Autopilot deployment training progress across your organization. The system consists of:

1. **Client Telemetry Application** - PowerShell script that runs on devices during ESP
2. **REST API Backend** - Flask-based API for data ingestion and querying
3. **PostgreSQL Database** - Structured storage for telemetry data
4. **Web Dashboard** - React-based UI for visualization and monitoring

## Features

### Client Application
- ✅ Lightweight PowerShell implementation
- ✅ Automatic deployment phase detection
- ✅ Progress percentage tracking
- ✅ Retry logic with exponential backoff
- ✅ Comprehensive error handling and logging
- ✅ Configurable telemetry intervals

### API Backend
- ✅ RESTful endpoints for telemetry ingestion
- ✅ Flexible querying with multiple filters
- ✅ API key authentication
- ✅ CORS support for frontend
- ✅ Health check endpoints
- ✅ Statistics and analytics endpoints

### Database
- ✅ Normalized PostgreSQL schema
- ✅ Indexed for optimal query performance
- ✅ Automatic triggers for data consistency
- ✅ Views for common queries
- ✅ Support for metadata via JSONB

### Web Dashboard
- ✅ Real-time deployment monitoring
- ✅ Interactive charts and graphs
- ✅ Client filtering and search
- ✅ Drill-down to individual device details
- ✅ Responsive design
- ✅ Automatic data refresh

## Quick Start

### Prerequisites

- **Python 3.8+** (for API)
- **PostgreSQL 12+** (for database)
- **Node.js 14+** (for dashboard)
- **PowerShell 5.1+** (for client)

### 1. Database Setup

```bash
# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
CREATE DATABASE nimbus_autopilot;
CREATE USER nimbus_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE nimbus_autopilot TO nimbus_user;
\q

# Initialize schema
cd database
psql -U nimbus_user -d nimbus_autopilot -f schema.sql
```

### 2. API Backend Setup

```bash
cd api
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your database credentials and API key

# Run the API
python app.py
```

The API will be available at `http://localhost:5000`.

### 3. Dashboard Setup

```bash
cd dashboard
npm install

# Configure environment
cp .env.example .env
# Edit .env with your API endpoint and key

# Run development server
npm start
```

The dashboard will be available at `http://localhost:3000`.

### 4. Client Deployment

Deploy the PowerShell script to your Autopilot devices:

```powershell
.\client\Send-AutopilotTelemetry.ps1 `
    -ApiEndpoint "https://your-api-endpoint.com" `
    -ApiKey "your_api_key"
```

## Architecture

```
┌─────────────────┐
│  Client Device  │
│   (PowerShell)  │
└────────┬────────┘
         │ HTTPS/JSON
         ▼
┌─────────────────┐      ┌──────────────┐
│   Flask API     │◄────►│  PostgreSQL  │
│   (Python)      │      │   Database   │
└────────┬────────┘      └──────────────┘
         │ REST API
         ▼
┌─────────────────┐
│  Web Dashboard  │
│    (React)      │
└─────────────────┘
```

## API Endpoints

### Health Check
```
GET /api/health
```

### Telemetry Ingestion
```
POST /api/telemetry
Headers: X-API-Key: your_api_key
```

### Query Clients
```
GET /api/clients?status=active&limit=100
GET /api/clients/{client_id}
Headers: X-API-Key: your_api_key
```

### Query Telemetry
```
GET /api/telemetry?client_id=DEVICE-001&phase_name=Device%20Setup
Headers: X-API-Key: your_api_key
```

### Statistics
```
GET /api/stats
GET /api/deployment-phases
Headers: X-API-Key: your_api_key
```

See [API Documentation](api/README.md) for complete details.

## Deployment Phases

The system tracks these deployment phases:

1. **Device Preparation** - Initial device setup
2. **Device Setup** - Core device configuration  
3. **Account Setup** - User account configuration
4. **Apps Installation** - Application deployment
5. **Policies Application** - Security and configuration policies
6. **Completion** - Deployment finished

## Docker Deployment

### Using Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Individual Containers

**Database:**
```bash
docker run --name nimbus-postgres \
  -e POSTGRES_DB=nimbus_autopilot \
  -e POSTGRES_USER=nimbus_user \
  -e POSTGRES_PASSWORD=your_password \
  -p 5432:5432 \
  -d postgres:15
```

**API:**
```bash
docker build -t nimbus-api ./api
docker run --name nimbus-api \
  -e DB_HOST=postgres \
  -e DB_PASSWORD=your_password \
  -e API_KEY=your_api_key \
  -p 5000:5000 \
  --link nimbus-postgres:postgres \
  -d nimbus-api
```

**Dashboard:**
```bash
docker build -t nimbus-dashboard ./dashboard
docker run --name nimbus-dashboard \
  -p 80:80 \
  -d nimbus-dashboard
```

## Security

### API Authentication
All API endpoints (except health check) require an API key in the `X-API-Key` header.

### HTTPS/TLS
Use HTTPS in production to encrypt data in transit. Configure your reverse proxy (nginx, Apache) or cloud load balancer.

### Database Security
- Use strong passwords
- Limit network access to database
- Enable SSL/TLS connections
- Regular backups

### Best Practices
- Rotate API keys regularly
- Use environment variables for secrets
- Enable firewall rules
- Monitor access logs
- Keep dependencies updated

## Testing

### API Tests
```bash
cd api

# Health check
curl http://localhost:5000/api/health

# Submit test telemetry
curl -X POST http://localhost:5000/api/telemetry \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_api_key" \
  -d @test_data.json

# Query clients
curl http://localhost:5000/api/clients \
  -H "X-API-Key: your_api_key"
```

### Client Tests
```powershell
# Test with verbose output
.\client\Send-AutopilotTelemetry.ps1 `
    -ApiEndpoint "http://localhost:5000" `
    -ApiKey "your_api_key" `
    -Verbose
```

## Monitoring

### Logs

**API Logs:**
- Application logs: stdout/stderr
- Access logs: configured in production server

**Client Logs:**
- Location: `C:\ProgramData\Nimbus\Logs\telemetry-YYYYMMDD.log`
- Rotation: Daily

**Database Logs:**
- PostgreSQL logs in configured log directory

### Metrics

Monitor these key metrics:
- API response times
- Database connection pool
- Active client count
- Failed telemetry submissions
- Average deployment duration

## Troubleshooting

### Client Issues
1. Check PowerShell execution policy
2. Verify network connectivity to API
3. Review client logs
4. Ensure admin privileges
5. Validate API key

### API Issues
1. Check database connectivity
2. Review API logs
3. Verify environment variables
4. Check firewall rules
5. Monitor resource usage

### Dashboard Issues
1. Verify API endpoint accessibility
2. Check browser console for errors
3. Confirm API key is valid
4. Review network requests
5. Clear browser cache

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review troubleshooting guide

## Roadmap

Future enhancements:
- [ ] WebSocket support for real-time updates
- [ ] Email/Slack notifications
- [ ] Advanced analytics and reporting
- [ ] Multi-tenant support
- [ ] Azure AD authentication
- [ ] Mobile app
- [ ] Automated remediation workflows

## Acknowledgments

Built with:
- Flask (API framework)
- PostgreSQL (Database)
- React (Frontend framework)
- Chart.js (Visualizations)
- PowerShell (Client application)

