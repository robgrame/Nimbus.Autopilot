// API service for communicating with the Nimbus backend
import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000';
const API_KEY = process.env.REACT_APP_API_KEY || 'default_api_key_change_in_production';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': API_KEY
  }
});

// Health check
export const checkHealth = async () => {
  const response = await apiClient.get('/api/health');
  return response.data;
};

// Get all clients
export const getClients = async (params = {}) => {
  const response = await apiClient.get('/api/clients', { params });
  return response.data;
};

// Get specific client details
export const getClientDetails = async (clientId) => {
  const response = await apiClient.get(`/api/clients/${clientId}`);
  return response.data;
};

// Query telemetry events
export const getTelemetry = async (params = {}) => {
  const response = await apiClient.get('/api/telemetry', { params });
  return response.data;
};

// Get deployment phases
export const getDeploymentPhases = async () => {
  const response = await apiClient.get('/api/deployment-phases');
  return response.data;
};

// Get statistics
export const getStatistics = async () => {
  const response = await apiClient.get('/api/stats');
  return response.data;
};

export default apiClient;
