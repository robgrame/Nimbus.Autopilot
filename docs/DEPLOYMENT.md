# Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Local Development](#local-development)
3. [Production Deployment](#production-deployment)
4. [Cloud Deployment](#cloud-deployment)
5. [Monitoring](#monitoring)
6. [Backup and Recovery](#backup-and-recovery)

## Prerequisites

### Required Software
- Python 3.8 or higher
- PostgreSQL 12 or higher
- Node.js 14 or higher
- Docker (optional, for containerized deployment)

### Required Resources
- Minimum 2GB RAM
- 20GB disk space
- Network connectivity for client devices

## Local Development

### 1. Database Setup

**Using PostgreSQL:**
```bash
# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# Create database
sudo -u postgres psql << EOF
CREATE DATABASE nimbus_autopilot;
CREATE USER nimbus_user WITH PASSWORD 'dev_password';
GRANT ALL PRIVILEGES ON DATABASE nimbus_autopilot TO nimbus_user;
\q
EOF

# Initialize schema
cd database
psql -U nimbus_user -d nimbus_autopilot -f schema.sql
```

**Using Docker:**
```bash
docker run --name nimbus-postgres \
  -e POSTGRES_DB=nimbus_autopilot \
  -e POSTGRES_USER=nimbus_user \
  -e POSTGRES_PASSWORD=dev_password \
  -p 5432:5432 \
  -v $(pwd)/database:/docker-entrypoint-initdb.d \
  -d postgres:15
```

### 2. API Development

```bash
cd api

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run development server
python app.py
```

### 3. Dashboard Development

```bash
cd dashboard

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Start development server
npm start
```

## Production Deployment

### Using Docker Compose (Recommended)

1. **Prepare environment:**
```bash
# Clone repository
git clone https://github.com/robgrame/Nimbus.Autopilot.git
cd Nimbus.Autopilot

# Configure environment
cp .env.example .env
# Edit .env with production values
```

2. **Start services:**
```bash
docker-compose up -d
```

3. **Verify deployment:**
```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f

# Test API
curl http://localhost:5000/api/health
```

### Manual Production Deployment

#### Database

```bash
# Install PostgreSQL
sudo apt-get install postgresql-15

# Configure PostgreSQL for production
sudo nano /etc/postgresql/15/main/postgresql.conf
# Set: max_connections = 100
# Set: shared_buffers = 256MB

# Create production database
sudo -u postgres psql << EOF
CREATE DATABASE nimbus_autopilot;
CREATE USER nimbus_user WITH ENCRYPTED PASSWORD 'strong_password_here';
GRANT ALL PRIVILEGES ON DATABASE nimbus_autopilot TO nimbus_user;
\q
EOF

# Initialize schema
psql -U nimbus_user -d nimbus_autopilot -f database/schema.sql

# Restart PostgreSQL
sudo systemctl restart postgresql
```

#### API Backend

```bash
# Create system user
sudo useradd -r -s /bin/false nimbus

# Install Python dependencies
cd api
python -m venv /opt/nimbus/venv
source /opt/nimbus/venv/bin/activate
pip install -r requirements.txt gunicorn

# Configure environment
sudo nano /opt/nimbus/.env
# Add production settings

# Create systemd service
sudo nano /etc/systemd/system/nimbus-api.service
```

**Service file content:**
```ini
[Unit]
Description=Nimbus Autopilot API
After=network.target postgresql.service

[Service]
Type=notify
User=nimbus
Group=nimbus
WorkingDirectory=/opt/nimbus/api
Environment="PATH=/opt/nimbus/venv/bin"
EnvironmentFile=/opt/nimbus/.env
ExecStart=/opt/nimbus/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 --timeout 120 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable nimbus-api
sudo systemctl start nimbus-api
```

#### Dashboard

```bash
# Build dashboard
cd dashboard
npm install
npm run build

# Install nginx
sudo apt-get install nginx

# Configure nginx
sudo nano /etc/nginx/sites-available/nimbus-dashboard
```

**Nginx configuration:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/nimbus-dashboard;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

```bash
# Deploy dashboard
sudo mkdir -p /var/www/nimbus-dashboard
sudo cp -r build/* /var/www/nimbus-dashboard/

# Enable site
sudo ln -s /etc/nginx/sites-available/nimbus-dashboard /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL/TLS Configuration

**Using Let's Encrypt:**
```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal is configured automatically
```

## Cloud Deployment

### Azure

#### Azure App Service (API)
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Create resource group
az group create --name nimbus-rg --location eastus

# Create PostgreSQL server
az postgres server create \
  --resource-group nimbus-rg \
  --name nimbus-postgres \
  --location eastus \
  --admin-user nimbusadmin \
  --admin-password "StrongPassword123!" \
  --sku-name B_Gen5_1

# Create database
az postgres db create \
  --resource-group nimbus-rg \
  --server-name nimbus-postgres \
  --name nimbus_autopilot

# Create App Service plan
az appservice plan create \
  --name nimbus-plan \
  --resource-group nimbus-rg \
  --sku B1 \
  --is-linux

# Create Web App
az webapp create \
  --resource-group nimbus-rg \
  --plan nimbus-plan \
  --name nimbus-api \
  --runtime "PYTHON:3.11"

# Configure app settings
az webapp config appsettings set \
  --resource-group nimbus-rg \
  --name nimbus-api \
  --settings \
    DB_HOST="nimbus-postgres.postgres.database.azure.com" \
    DB_NAME="nimbus_autopilot" \
    DB_USER="nimbusadmin@nimbus-postgres" \
    API_KEY="your_api_key"

# Deploy code
cd api
az webapp up --resource-group nimbus-rg --name nimbus-api
```

#### Azure Static Web Apps (Dashboard)
```bash
# Build dashboard
cd dashboard
npm run build

# Create Static Web App
az staticwebapp create \
  --name nimbus-dashboard \
  --resource-group nimbus-rg \
  --source build \
  --location eastus \
  --branch main \
  --app-location "dashboard" \
  --output-location "build"
```

### AWS

#### RDS (Database)
```bash
# Install AWS CLI
pip install awscli

# Configure AWS CLI
aws configure

# Create RDS instance
aws rds create-db-instance \
  --db-instance-identifier nimbus-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username nimbusadmin \
  --master-user-password StrongPassword123! \
  --allocated-storage 20
```

#### Elastic Beanstalk (API)
```bash
# Install EB CLI
pip install awsebcli

# Initialize EB application
cd api
eb init -p python-3.11 nimbus-api

# Create environment
eb create nimbus-api-prod

# Set environment variables
eb setenv \
  DB_HOST="nimbus-postgres.xxx.rds.amazonaws.com" \
  DB_NAME="nimbus_autopilot" \
  API_KEY="your_api_key"

# Deploy
eb deploy
```

#### S3 + CloudFront (Dashboard)
```bash
cd dashboard
npm run build

# Create S3 bucket
aws s3 mb s3://nimbus-dashboard

# Upload build
aws s3 sync build/ s3://nimbus-dashboard

# Configure static website hosting
aws s3 website s3://nimbus-dashboard \
  --index-document index.html \
  --error-document index.html

# Create CloudFront distribution (optional)
aws cloudfront create-distribution \
  --origin-domain-name nimbus-dashboard.s3.amazonaws.com
```

## Monitoring

### Application Monitoring

**API Metrics:**
```python
# Add to app.py for Prometheus metrics
from prometheus_client import Counter, Histogram, generate_latest

request_count = Counter('http_requests_total', 'Total HTTP requests')
request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration')
```

**Health Checks:**
```bash
# API health
curl http://localhost:5000/api/health

# Database connectivity
psql -U nimbus_user -d nimbus_autopilot -c "SELECT 1"
```

### Log Monitoring

**API Logs:**
```bash
# Systemd service logs
sudo journalctl -u nimbus-api -f

# Docker logs
docker-compose logs -f api
```

**Database Logs:**
```bash
# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

## Backup and Recovery

### Database Backup

**Automated backup script:**
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/nimbus"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/nimbus_autopilot_$TIMESTAMP.sql"

# Create backup directory
mkdir -p $BACKUP_DIR

# Perform backup
pg_dump -U nimbus_user -d nimbus_autopilot > $BACKUP_FILE

# Compress
gzip $BACKUP_FILE

# Remove backups older than 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE.gz"
```

**Schedule with cron:**
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /opt/nimbus/backup.sh
```

### Database Restore

```bash
# Restore from backup
gunzip -c /backups/nimbus/nimbus_autopilot_20240115_020000.sql.gz | \
  psql -U nimbus_user -d nimbus_autopilot
```

## Security Checklist

- [ ] Change default passwords
- [ ] Enable firewall rules
- [ ] Configure SSL/TLS
- [ ] Set up API key rotation
- [ ] Enable database encryption
- [ ] Configure security groups (cloud)
- [ ] Set up monitoring alerts
- [ ] Regular security updates
- [ ] Backup verification
- [ ] Access logging enabled

## Troubleshooting

### API Won't Start
```bash
# Check logs
sudo journalctl -u nimbus-api -n 50

# Verify database connection
psql -U nimbus_user -h localhost -d nimbus_autopilot

# Check port availability
sudo netstat -tulpn | grep 5000
```

### Dashboard Not Loading
```bash
# Check nginx status
sudo systemctl status nginx

# Verify build
ls -la /var/www/nimbus-dashboard

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

### Database Connection Issues
```bash
# Verify PostgreSQL is running
sudo systemctl status postgresql

# Check connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity"

# Verify credentials
psql -U nimbus_user -d nimbus_autopilot -h localhost
```
