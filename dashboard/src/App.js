import React, { useState } from 'react';
import Dashboard from './components/Dashboard';
import ClientList from './components/ClientList';
import ClientDetails from './components/ClientDetails';
import './App.css';

function App() {
  const [selectedClient, setSelectedClient] = useState(null);
  const [activeTab, setActiveTab] = useState('dashboard');

  return (
    <div className="app">
      <header className="app-header">
        <h1>Nimbus Autopilot Dashboard</h1>
        <nav className="nav-tabs">
          <button 
            className={`nav-tab ${activeTab === 'dashboard' ? 'active' : ''}`}
            onClick={() => setActiveTab('dashboard')}
          >
            Dashboard
          </button>
          <button 
            className={`nav-tab ${activeTab === 'clients' ? 'active' : ''}`}
            onClick={() => setActiveTab('clients')}
          >
            Clients
          </button>
        </nav>
      </header>

      <main className="app-main">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'clients' && <ClientList onClientSelect={setSelectedClient} />}
      </main>

      {selectedClient && (
        <ClientDetails 
          clientId={selectedClient} 
          onClose={() => setSelectedClient(null)} 
        />
      )}
    </div>
  );
}

export default App;
