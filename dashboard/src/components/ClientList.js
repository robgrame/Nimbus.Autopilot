import React, { useState, useEffect } from 'react';
import { getClients } from '../services/api';
import { formatDistance } from 'date-fns';

const ClientList = ({ onClientSelect }) => {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filters, setFilters] = useState({
    status: '',
    search: ''
  });

  const fetchClients = async () => {
    try {
      setLoading(true);
      const params = {};
      if (filters.status) params.status = filters.status;
      
      const data = await getClients(params);
      let clientList = data.clients || [];
      
      // Apply search filter
      if (filters.search) {
        const searchLower = filters.search.toLowerCase();
        clientList = clientList.filter(c => 
          c.client_id?.toLowerCase().includes(searchLower) ||
          c.device_name?.toLowerCase().includes(searchLower)
        );
      }
      
      setClients(clientList);
      setError(null);
    } catch (err) {
      setError('Failed to load clients');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchClients();
    const interval = setInterval(fetchClients, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, [filters]);

  const getStatusBadgeClass = (status) => {
    switch (status) {
      case 'active': return 'badge-active';
      case 'completed': return 'badge-completed';
      case 'failed': return 'badge-failed';
      default: return 'badge-default';
    }
  };

  return (
    <div className="client-list">
      <div className="list-header">
        <h2>Clients</h2>
        <div className="filters">
          <input
            type="text"
            placeholder="Search by ID or name..."
            value={filters.search}
            onChange={(e) => setFilters({ ...filters, search: e.target.value })}
            className="search-input"
          />
          <select
            value={filters.status}
            onChange={(e) => setFilters({ ...filters, status: e.target.value })}
            className="status-filter"
          >
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="completed">Completed</option>
            <option value="failed">Failed</option>
          </select>
          <button onClick={fetchClients} className="refresh-btn">Refresh</button>
        </div>
      </div>

      {loading && clients.length === 0 && <div className="loading">Loading clients...</div>}
      {error && <div className="error">{error}</div>}

      <div className="client-table-container">
        <table className="client-table">
          <thead>
            <tr>
              <th>Client ID</th>
              <th>Device Name</th>
              <th>Profile</th>
              <th>Status</th>
              <th>Last Seen</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {clients.map((client) => (
              <tr key={client.client_id}>
                <td>{client.client_id}</td>
                <td>{client.device_name || 'N/A'}</td>
                <td>{client.deployment_profile || 'N/A'}</td>
                <td>
                  <span className={`status-badge ${getStatusBadgeClass(client.status)}`}>
                    {client.status}
                  </span>
                </td>
                <td>
                  {client.last_seen 
                    ? formatDistance(new Date(client.last_seen), new Date(), { addSuffix: true })
                    : 'Never'
                  }
                </td>
                <td>
                  <button 
                    onClick={() => onClientSelect(client.client_id)}
                    className="view-btn"
                  >
                    View Details
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        
        {clients.length === 0 && !loading && (
          <div className="no-data">No clients found</div>
        )}
      </div>
    </div>
  );
};

export default ClientList;
