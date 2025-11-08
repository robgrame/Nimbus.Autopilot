import React, { useState, useEffect } from 'react';
import { getClientDetails } from '../services/api';
import { format } from 'date-fns';
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend } from 'chart.js';
import { Line } from 'react-chartjs-2';

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Legend);

const ClientDetails = ({ clientId, onClose }) => {
  const [details, setDetails] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchDetails = async () => {
      try {
        setLoading(true);
        const data = await getClientDetails(clientId);
        setDetails(data);
        setError(null);
      } catch (err) {
        setError('Failed to load client details');
        console.error(err);
      } finally {
        setLoading(false);
      }
    };

    fetchDetails();
  }, [clientId]);

  if (loading) {
    return <div className="modal-overlay"><div className="loading">Loading details...</div></div>;
  }

  if (error) {
    return (
      <div className="modal-overlay">
        <div className="modal">
          <div className="error">{error}</div>
          <button onClick={onClose} className="close-btn">Close</button>
        </div>
      </div>
    );
  }

  if (!details) {
    return null;
  }

  const { client, events } = details;

  // Prepare progress chart data
  const progressData = {
    labels: events?.slice().reverse().map(e => 
      format(new Date(e.event_timestamp), 'HH:mm:ss')
    ) || [],
    datasets: [{
      label: 'Progress %',
      data: events?.slice().reverse().map(e => e.progress_percentage || 0) || [],
      borderColor: 'rgb(75, 192, 192)',
      backgroundColor: 'rgba(75, 192, 192, 0.2)',
      tension: 0.1
    }]
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      y: {
        beginAtZero: true,
        max: 100
      }
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal client-details-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Client Details</h2>
          <button onClick={onClose} className="close-btn">×</button>
        </div>

        <div className="modal-body">
          <div className="detail-section">
            <h3>Device Information</h3>
            <div className="detail-grid">
              <div className="detail-item">
                <span className="detail-label">Client ID:</span>
                <span className="detail-value">{client.client_id}</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Device Name:</span>
                <span className="detail-value">{client.device_name || 'N/A'}</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Deployment Profile:</span>
                <span className="detail-value">{client.deployment_profile || 'N/A'}</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Status:</span>
                <span className="detail-value">{client.status}</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Enrolled:</span>
                <span className="detail-value">
                  {client.enrolled_at ? format(new Date(client.enrolled_at), 'PPpp') : 'N/A'}
                </span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Last Seen:</span>
                <span className="detail-value">
                  {client.last_seen ? format(new Date(client.last_seen), 'PPpp') : 'N/A'}
                </span>
              </div>
            </div>
          </div>

          <div className="detail-section">
            <h3>Progress Over Time</h3>
            <div className="chart-container" style={{ height: '300px' }}>
              <Line data={progressData} options={chartOptions} />
            </div>
          </div>

          <div className="detail-section">
            <h3>Telemetry Events</h3>
            <div className="events-table-container">
              <table className="events-table">
                <thead>
                  <tr>
                    <th>Timestamp</th>
                    <th>Phase</th>
                    <th>Event Type</th>
                    <th>Progress</th>
                    <th>Status</th>
                    <th>Duration</th>
                  </tr>
                </thead>
                <tbody>
                  {events?.map((event) => (
                    <tr key={event.event_id}>
                      <td>{format(new Date(event.event_timestamp), 'PPpp')}</td>
                      <td>{event.phase_name || 'N/A'}</td>
                      <td>{event.event_type}</td>
                      <td>{event.progress_percentage}%</td>
                      <td>{event.status}</td>
                      <td>{event.duration_seconds ? `${Math.floor(event.duration_seconds / 60)}m` : 'N/A'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              
              {(!events || events.length === 0) && (
                <div className="no-data">No events recorded</div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ClientDetails;
