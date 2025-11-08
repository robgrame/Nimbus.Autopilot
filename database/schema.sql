-- Database schema for Nimbus Autopilot Telemetry System
-- PostgreSQL compatible

-- Table to store client device information
CREATE TABLE IF NOT EXISTS clients (
    client_id VARCHAR(255) PRIMARY KEY,
    device_name VARCHAR(255),
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deployment_profile VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to store deployment phases
CREATE TABLE IF NOT EXISTS deployment_phases (
    phase_id SERIAL PRIMARY KEY,
    phase_name VARCHAR(100) UNIQUE NOT NULL,
    phase_order INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default deployment phases
INSERT INTO deployment_phases (phase_name, phase_order, description) VALUES
    ('Device Preparation', 1, 'Initial device setup and preparation'),
    ('Device Setup', 2, 'Core device configuration'),
    ('Account Setup', 3, 'User account configuration'),
    ('Apps Installation', 4, 'Application deployment'),
    ('Policies Application', 5, 'Security and configuration policies'),
    ('Completion', 6, 'Final deployment stage')
ON CONFLICT (phase_name) DO NOTHING;

-- Table to store telemetry events
CREATE TABLE IF NOT EXISTS telemetry_events (
    event_id SERIAL PRIMARY KEY,
    client_id VARCHAR(255) NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    phase_id INTEGER REFERENCES deployment_phases(phase_id),
    event_type VARCHAR(100) NOT NULL,
    event_timestamp TIMESTAMP NOT NULL,
    progress_percentage INTEGER CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    status VARCHAR(50),
    duration_seconds INTEGER,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_client FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_telemetry_client_id ON telemetry_events(client_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_timestamp ON telemetry_events(event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_phase ON telemetry_events(phase_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_status ON telemetry_events(status);
CREATE INDEX IF NOT EXISTS idx_clients_status ON clients(status);
CREATE INDEX IF NOT EXISTS idx_clients_last_seen ON clients(last_seen DESC);

-- Create view for easy querying of deployment progress
CREATE OR REPLACE VIEW v_deployment_progress AS
SELECT 
    c.client_id,
    c.device_name,
    c.deployment_profile,
    c.status as client_status,
    dp.phase_name,
    dp.phase_order,
    te.progress_percentage,
    te.event_timestamp,
    te.duration_seconds,
    te.error_message,
    EXTRACT(EPOCH FROM (te.event_timestamp - c.enrolled_at)) as total_elapsed_seconds
FROM clients c
LEFT JOIN telemetry_events te ON c.client_id = te.client_id
LEFT JOIN deployment_phases dp ON te.phase_id = dp.phase_id
WHERE te.event_id IN (
    SELECT MAX(event_id) 
    FROM telemetry_events 
    GROUP BY client_id
);

-- Function to update last_seen timestamp
CREATE OR REPLACE FUNCTION update_client_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE clients 
    SET last_seen = NEW.event_timestamp,
        updated_at = CURRENT_TIMESTAMP
    WHERE client_id = NEW.client_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update client last_seen
CREATE TRIGGER trigger_update_last_seen
AFTER INSERT ON telemetry_events
FOR EACH ROW
EXECUTE FUNCTION update_client_last_seen();
