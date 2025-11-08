import React, { useState, useEffect } from 'react';
import { getStatistics } from '../services/api';
import { Chart as ChartJS, ArcElement, CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend } from 'chart.js';
import { Pie, Bar } from 'react-chartjs-2';

ChartJS.register(ArcElement, CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchStats = async () => {
    try {
      setLoading(true);
      const data = await getStatistics();
      setStats(data);
      setError(null);
    } catch (err) {
      setError('Failed to load statistics');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, []);

  if (loading && !stats) {
    return <div className="loading">Loading statistics...</div>;
  }

  if (error) {
    return <div className="error">{error}</div>;
  }

  if (!stats) {
    return null;
  }

  // Prepare data for status chart
  const statusData = {
    labels: stats.clients_by_status?.map(s => s.status) || [],
    datasets: [{
      label: 'Clients by Status',
      data: stats.clients_by_status?.map(s => s.count) || [],
      backgroundColor: [
        'rgba(75, 192, 192, 0.6)',
        'rgba(54, 162, 235, 0.6)',
        'rgba(255, 206, 86, 0.6)',
        'rgba(255, 99, 132, 0.6)',
      ],
      borderColor: [
        'rgba(75, 192, 192, 1)',
        'rgba(54, 162, 235, 1)',
        'rgba(255, 206, 86, 1)',
        'rgba(255, 99, 132, 1)',
      ],
      borderWidth: 1,
    }]
  };

  const formatDuration = (seconds) => {
    if (!seconds) return 'N/A';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  };

  return (
    <div className="dashboard">
      <div className="stats-grid">
        <div className="stat-card">
          <h3>Total Clients</h3>
          <div className="stat-value">{stats.total_clients}</div>
        </div>
        
        <div className="stat-card">
          <h3>Active Deployments</h3>
          <div className="stat-value">{stats.active_deployments}</div>
        </div>
        
        <div className="stat-card">
          <h3>Avg. Duration</h3>
          <div className="stat-value">{formatDuration(stats.average_duration_seconds)}</div>
        </div>
      </div>

      <div className="charts-grid">
        <div className="chart-card">
          <h3>Clients by Status</h3>
          <div className="chart-container">
            <Pie data={statusData} options={{ maintainAspectRatio: false }} />
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
