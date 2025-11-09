-- Database schema for Nimbus Autopilot Telemetry System
-- SQL Server compatible

-- Table to store client device information
CREATE TABLE clients (
    client_id NVARCHAR(255) PRIMARY KEY,
    device_name NVARCHAR(255),
    enrolled_at DATETIME2 DEFAULT GETUTCDATE(),
    last_seen DATETIME2 DEFAULT GETUTCDATE(),
    deployment_profile NVARCHAR(255),
    status NVARCHAR(50) DEFAULT 'active',
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE()
);

-- Table to store deployment phases
CREATE TABLE deployment_phases (
    phase_id INT IDENTITY(1,1) PRIMARY KEY,
    phase_name NVARCHAR(100) UNIQUE NOT NULL,
    phase_order INT NOT NULL,
    description NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETUTCDATE()
);

-- Insert default deployment phases
IF NOT EXISTS (SELECT 1 FROM deployment_phases WHERE phase_name = 'Device Preparation')
BEGIN
    INSERT INTO deployment_phases (phase_name, phase_order, description) VALUES
        ('Device Preparation', 1, 'Initial device setup and preparation'),
        ('Device Setup', 2, 'Core device configuration'),
        ('Account Setup', 3, 'User account configuration'),
        ('Apps Installation', 4, 'Application deployment'),
        ('Policies Application', 5, 'Security and configuration policies'),
        ('Completion', 6, 'Final deployment stage');
END;

-- Table to store telemetry events
CREATE TABLE telemetry_events (
    event_id INT IDENTITY(1,1) PRIMARY KEY,
    client_id NVARCHAR(255) NOT NULL,
    phase_id INT,
    event_type NVARCHAR(100) NOT NULL,
    event_timestamp DATETIME2 NOT NULL,
    progress_percentage INT CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    status NVARCHAR(50),
    duration_seconds INT,
    error_message NVARCHAR(MAX),
    metadata NVARCHAR(MAX),  -- JSON stored as string
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT FK_telemetry_client FOREIGN KEY (client_id) REFERENCES clients(client_id) ON DELETE CASCADE,
    CONSTRAINT FK_telemetry_phase FOREIGN KEY (phase_id) REFERENCES deployment_phases(phase_id) ON DELETE SET NULL
);

-- Create indexes for better query performance
CREATE NONCLUSTERED INDEX idx_telemetry_client_id ON telemetry_events(client_id);
CREATE NONCLUSTERED INDEX idx_telemetry_timestamp ON telemetry_events(event_timestamp DESC);
CREATE NONCLUSTERED INDEX idx_telemetry_phase ON telemetry_events(phase_id);
CREATE NONCLUSTERED INDEX idx_telemetry_status ON telemetry_events(status);
CREATE NONCLUSTERED INDEX idx_clients_status ON clients(status);
CREATE NONCLUSTERED INDEX idx_clients_last_seen ON clients(last_seen DESC);

-- Create view for easy querying of deployment progress
GO
CREATE OR ALTER VIEW v_deployment_progress AS
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
    DATEDIFF(SECOND, c.enrolled_at, te.event_timestamp) as total_elapsed_seconds
FROM clients c
LEFT JOIN telemetry_events te ON c.client_id = te.client_id
LEFT JOIN deployment_phases dp ON te.phase_id = dp.phase_id
WHERE te.event_id IN (
    SELECT MAX(event_id) 
    FROM telemetry_events 
    GROUP BY client_id
);
GO

-- Trigger to automatically update client last_seen
-- Note: SQL Server uses triggers differently than PostgreSQL
CREATE OR ALTER TRIGGER trg_update_client_last_seen
ON telemetry_events
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE clients 
    SET last_seen = i.event_timestamp,
        updated_at = GETUTCDATE()
    FROM clients c
    INNER JOIN inserted i ON c.client_id = i.client_id;
END;
GO
