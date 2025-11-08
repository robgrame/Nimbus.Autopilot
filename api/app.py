"""
Nimbus Autopilot Telemetry API
Flask-based REST API for receiving and querying Autopilot deployment telemetry
"""
import os
import json
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import RealDictCursor, Json
from functools import wraps

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME', 'nimbus_autopilot'),
    'user': os.getenv('DB_USER', 'nimbus_user'),
    'password': os.getenv('DB_PASSWORD', '')
}

# API Key for authentication
API_KEY = os.getenv('API_KEY', 'default_api_key_change_in_production')


def get_db_connection():
    """Create and return a database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        app.logger.error(f"Database connection error: {e}")
        raise


def require_api_key(f):
    """Decorator to require API key authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('X-API-Key')
        if not api_key or api_key != API_KEY:
            return jsonify({'error': 'Unauthorized', 'message': 'Invalid or missing API key'}), 401
        return f(*args, **kwargs)
    return decorated_function


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({
            'status': 'healthy',
            'database': 'connected',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'database': 'disconnected',
            'error': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 503


@app.route('/api/telemetry', methods=['POST'])
@require_api_key
def ingest_telemetry():
    """
    Ingest telemetry data from client devices
    
    Expected JSON payload:
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
    """
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['client_id', 'event_type', 'event_timestamp']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': 'Bad Request', 'message': f'Missing required field: {field}'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Upsert client record
        cursor.execute("""
            INSERT INTO clients (client_id, device_name, deployment_profile, enrolled_at)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (client_id) DO UPDATE
            SET device_name = EXCLUDED.device_name,
                deployment_profile = EXCLUDED.deployment_profile,
                updated_at = CURRENT_TIMESTAMP
        """, (
            data['client_id'],
            data.get('device_name'),
            data.get('deployment_profile'),
            data.get('event_timestamp')
        ))
        
        # Get phase_id if phase_name is provided
        phase_id = None
        if 'phase_name' in data and data['phase_name']:
            cursor.execute("SELECT phase_id FROM deployment_phases WHERE phase_name = %s", (data['phase_name'],))
            result = cursor.fetchone()
            if result:
                phase_id = result[0]
        
        # Insert telemetry event
        cursor.execute("""
            INSERT INTO telemetry_events 
            (client_id, phase_id, event_type, event_timestamp, progress_percentage, 
             status, duration_seconds, error_message, metadata)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING event_id
        """, (
            data['client_id'],
            phase_id,
            data['event_type'],
            data['event_timestamp'],
            data.get('progress_percentage'),
            data.get('status'),
            data.get('duration_seconds'),
            data.get('error_message'),
            Json(data.get('metadata', {}))
        ))
        
        event_id = cursor.fetchone()[0]
        conn.commit()
        cursor.close()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Telemetry data received',
            'event_id': event_id
        }), 201
        
    except Exception as e:
        app.logger.error(f"Error ingesting telemetry: {e}")
        return jsonify({'error': 'Internal Server Error', 'message': str(e)}), 500


@app.route('/api/clients', methods=['GET'])
@require_api_key
def get_clients():
    """
    Get list of all clients with optional filtering
    
    Query parameters:
    - status: Filter by client status
    - limit: Number of results (default: 100)
    - offset: Pagination offset (default: 0)
    """
    try:
        status = request.args.get('status')
        limit = int(request.args.get('limit', 100))
        offset = int(request.args.get('offset', 0))
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        query = "SELECT * FROM clients"
        params = []
        
        if status:
            query += " WHERE status = %s"
            params.append(status)
        
        query += " ORDER BY last_seen DESC LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        clients = cursor.fetchall()
        
        # Get total count
        count_query = "SELECT COUNT(*) as total FROM clients"
        if status:
            count_query += " WHERE status = %s"
            cursor.execute(count_query, [status])
        else:
            cursor.execute(count_query)
        
        total = cursor.fetchone()['total']
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'clients': clients,
            'total': total,
            'limit': limit,
            'offset': offset
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching clients: {e}")
        return jsonify({'error': 'Internal Server Error', 'message': str(e)}), 500


@app.route('/api/clients/<client_id>', methods=['GET'])
@require_api_key
def get_client_details(client_id):
    """Get detailed information for a specific client"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Get client info
        cursor.execute("SELECT * FROM clients WHERE client_id = %s", (client_id,))
        client = cursor.fetchone()
        
        if not client:
            return jsonify({'error': 'Not Found', 'message': 'Client not found'}), 404
        
        # Get telemetry events
        cursor.execute("""
            SELECT te.*, dp.phase_name, dp.phase_order
            FROM telemetry_events te
            LEFT JOIN deployment_phases dp ON te.phase_id = dp.phase_id
            WHERE te.client_id = %s
            ORDER BY te.event_timestamp DESC
        """, (client_id,))
        events = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'client': client,
            'events': events
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching client details: {e}")
        return jsonify({'error': 'Internal Server Error', 'message': str(e)}), 500


@app.route('/api/telemetry', methods=['GET'])
@require_api_key
def query_telemetry():
    """
    Query telemetry events with filtering
    
    Query parameters:
    - client_id: Filter by client ID
    - phase_name: Filter by deployment phase
    - status: Filter by event status
    - from_date: Start date (ISO format)
    - to_date: End date (ISO format)
    - limit: Number of results (default: 100)
    - offset: Pagination offset (default: 0)
    """
    try:
        client_id = request.args.get('client_id')
        phase_name = request.args.get('phase_name')
        status = request.args.get('status')
        from_date = request.args.get('from_date')
        to_date = request.args.get('to_date')
        limit = int(request.args.get('limit', 100))
        offset = int(request.args.get('offset', 0))
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT te.*, dp.phase_name, dp.phase_order, c.device_name
            FROM telemetry_events te
            LEFT JOIN deployment_phases dp ON te.phase_id = dp.phase_id
            LEFT JOIN clients c ON te.client_id = c.client_id
            WHERE 1=1
        """
        params = []
        
        if client_id:
            query += " AND te.client_id = %s"
            params.append(client_id)
        
        if phase_name:
            query += " AND dp.phase_name = %s"
            params.append(phase_name)
        
        if status:
            query += " AND te.status = %s"
            params.append(status)
        
        if from_date:
            query += " AND te.event_timestamp >= %s"
            params.append(from_date)
        
        if to_date:
            query += " AND te.event_timestamp <= %s"
            params.append(to_date)
        
        query += " ORDER BY te.event_timestamp DESC LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        events = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'events': events,
            'limit': limit,
            'offset': offset
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error querying telemetry: {e}")
        return jsonify({'error': 'Internal Server Error', 'message': str(e)}), 500


@app.route('/api/deployment-phases', methods=['GET'])
@require_api_key
def get_deployment_phases():
    """Get all deployment phases"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("SELECT * FROM deployment_phases ORDER BY phase_order")
        phases = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return jsonify({'phases': phases}), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching deployment phases: {e}")
        return jsonify({'error': 'Internal Server Error', 'message': str(e)}), 500


@app.route('/api/stats', methods=['GET'])
@require_api_key
def get_statistics():
    """Get overall deployment statistics"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Total clients
        cursor.execute("SELECT COUNT(*) as total FROM clients")
        total_clients = cursor.fetchone()['total']
        
        # Clients by status
        cursor.execute("""
            SELECT status, COUNT(*) as count 
            FROM clients 
            GROUP BY status
        """)
        clients_by_status = cursor.fetchall()
        
        # Active deployments (last seen in last hour)
        cursor.execute("""
            SELECT COUNT(*) as active 
            FROM clients 
            WHERE last_seen > NOW() - INTERVAL '1 hour'
        """)
        active_deployments = cursor.fetchone()['active']
        
        # Average deployment duration
        cursor.execute("""
            SELECT AVG(EXTRACT(EPOCH FROM (last_seen - enrolled_at))) as avg_duration
            FROM clients
            WHERE status = 'completed'
        """)
        avg_duration = cursor.fetchone()['avg_duration']
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'total_clients': total_clients,
            'clients_by_status': clients_by_status,
            'active_deployments': active_deployments,
            'average_duration_seconds': avg_duration
        }), 200
        
    except Exception as e:
        app.logger.error(f"Error fetching statistics: {e}")
        return jsonify({'error': 'Internal Server Error', 'message': str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not Found', 'message': 'Endpoint not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal Server Error', 'message': 'An unexpected error occurred'}), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
