# SignalR Real-time Dashboard

This document describes the SignalR integration for real-time telemetry updates in Nimbus Autopilot.

## Overview

The .NET API now includes SignalR support with Razor MVC pages, enabling real-time telemetry updates without requiring page refreshes. This provides instant visibility into device deployment progress.

## Features

### SignalR Hub
- **TelemetryHub**: Central hub for broadcasting telemetry updates to connected clients
- **Endpoint**: `/hubs/telemetry`
- **Automatic reconnection**: Handles connection drops gracefully

### Razor MVC Pages
- **Home Page** (`/`): Landing page with feature overview
- **Dashboard** (`/Home/Dashboard`): Real-time telemetry monitoring dashboard

### Real-time Updates
- Automatic broadcasting when new telemetry is received via API
- Visual indicators for connection status
- Animated highlighting of new telemetry events
- Statistics updated every 30 seconds

## Architecture

### Components

1. **TelemetryHub** (`/Hubs/TelemetryHub.cs`)
   - SignalR hub for managing WebSocket connections
   - Supports group subscriptions for filtered updates

2. **HomeController** (`/Controllers/HomeController.cs`)
   - MVC controller serving Razor views
   - Actions: `Index`, `Dashboard`

3. **TelemetryController** (enhanced)
   - Now broadcasts telemetry updates via SignalR when data is ingested
   - Uses `IHubContext<TelemetryHub>` for server-side broadcasting

4. **Razor Views** (`/Views/`)
   - `Home/Index.cshtml`: Welcome page
   - `Home/Dashboard.cshtml`: Real-time dashboard with SignalR client
   - `Shared/_Layout.cshtml`: Common layout with Bootstrap and SignalR scripts

## Usage

### Accessing the Dashboard

1. Start the API:
   ```bash
   cd api-dotnet/Nimbus.Autopilot.Api
   dotnet run
   ```

2. Open browser and navigate to:
   - Home: `http://localhost:5000/`
   - Dashboard: `http://localhost:5000/Home/Dashboard`

### Dashboard Features

#### Connection Status
- **Green pulsing dot**: Connected to SignalR hub
- **Red dot**: Disconnected (will auto-reconnect)

#### Real-time Statistics
- **Total Clients**: All registered devices
- **Active Deployments**: Devices seen in last hour
- **Completed**: Successfully deployed devices
- **Failed**: Deployments with errors

#### Telemetry Events
- Shows last 20 events in real-time
- New events highlighted with blue shadow
- Progress bars showing deployment completion
- Color-coded status badges:
  - 🟢 Green: Completed
  - 🔵 Blue: In Progress
  - 🔴 Red: Failed/Error
  - 🟡 Yellow: Pending

### SignalR Client Usage

The dashboard includes JavaScript code that:

1. Establishes SignalR connection:
   ```javascript
   const connection = new signalR.HubConnectionBuilder()
       .withUrl("/hubs/telemetry")
       .withAutomaticReconnect()
       .build();
   ```

2. Listens for telemetry updates:
   ```javascript
   connection.on("ReceiveTelemetryUpdate", function (data) {
       // Handle new telemetry data
   });
   ```

3. Manages connection state with auto-reconnect

## API Integration

### Broadcasting from Server

When telemetry is received via the API endpoint, it's automatically broadcast to all connected clients:

```csharp
await _hubContext.Clients.All.SendAsync("ReceiveTelemetryUpdate", telemetryData);
```

### CORS Configuration

CORS is configured to support SignalR connections from the dashboard:

```csharp
policy.WithOrigins("http://localhost:3000", "http://localhost:5000", "https://localhost:5001")
      .AllowAnyMethod()
      .AllowAnyHeader()
      .AllowCredentials();
```

## Configuration

### SignalR Settings

Default configuration in `Program.cs`:
- Automatic reconnection enabled
- JSON serialization using snake_case (consistent with REST API)
- Hub endpoint: `/hubs/telemetry`

### Customization

To modify SignalR behavior, update `Program.cs`:

```csharp
builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = true; // For debugging
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromSeconds(30);
});
```

## Testing

### Manual Testing

1. Start the API
2. Open dashboard in browser
3. Verify connection status shows "Connected"
4. Send test telemetry via API:
   ```bash
   curl -X POST http://localhost:5000/api/telemetry \
     -H "Content-Type: application/json" \
     -H "X-API-Key: your-api-key" \
     -d '{
       "client_id": "test-device-001",
       "device_name": "TestDevice",
       "event_type": "phase_start",
       "event_timestamp": "2025-11-09T08:00:00Z",
       "phase_name": "Device Setup",
       "progress_percentage": 50,
       "status": "in_progress"
     }'
   ```
5. Verify event appears in dashboard in real-time

### Multiple Clients

Open dashboard in multiple browser tabs/windows to verify:
- All clients receive broadcasts
- Connection status updates correctly
- No duplicate events

## Security Considerations

### Current Implementation
- API key authentication still required for telemetry ingestion
- SignalR hub is publicly accessible (read-only)
- CORS limited to specific origins

### Production Recommendations
1. Add authentication to SignalR hub:
   ```csharp
   [Authorize]
   public class TelemetryHub : Hub { ... }
   ```

2. Implement authorization for dashboard access
3. Use HTTPS in production
4. Restrict CORS origins to production domains
5. Consider rate limiting for hub connections

## Troubleshooting

### Connection Issues
- **Check browser console** for SignalR errors
- **Verify CORS settings** match your hosting configuration
- **Check firewall** allows WebSocket connections
- **Ensure API is running** before opening dashboard

### Events Not Appearing
- Verify API key is valid for telemetry ingestion
- Check server logs for errors
- Ensure database connection is working
- Verify SignalR hub context injection in controller

### Performance
- Dashboard keeps only last 20 events in memory
- Statistics refresh every 30 seconds
- Consider pagination for high-volume scenarios

## Browser Compatibility

The dashboard uses:
- **Bootstrap 5.3**: Modern browsers
- **SignalR 7.0**: Supports WebSockets, Server-Sent Events, Long Polling
- **ES6 JavaScript**: Modern browsers (Chrome, Firefox, Edge, Safari)

Tested on:
- Chrome 90+
- Firefox 88+
- Edge 90+
- Safari 14+

## Future Enhancements

Potential improvements:
- [ ] Filtering events by client, phase, or status
- [ ] Historical event playback
- [ ] Export telemetry data to CSV/Excel
- [ ] Custom alert notifications
- [ ] Client grouping for targeted broadcasts
- [ ] Dark mode support
- [ ] Mobile-responsive optimizations
- [ ] Advanced charts and visualizations

## Dependencies

New NuGet packages added:
- `Microsoft.AspNetCore.SignalR` (1.2.0)

Additional dependencies (transitive):
- `Microsoft.AspNetCore.SignalR.Core`
- `Microsoft.AspNetCore.Http.Connections`
- `Microsoft.AspNetCore.WebSockets`

## Compatibility

This implementation is compatible with:
- .NET 8.0
- Existing REST API endpoints (unchanged)
- PowerShell client (no changes required)
- React dashboard (can run alongside)

## Migration Notes

### From REST-only to SignalR
The REST API endpoints remain fully functional. The dashboard can be used alongside the React frontend, or as a replacement for real-time monitoring needs.

### Existing Deployments
No changes required to:
- Database schema
- Client telemetry script
- Docker configuration (unless you want to expose new ports)

## Support

For issues or questions:
1. Check this documentation
2. Review browser console for errors
3. Check server logs for exceptions
4. Verify all prerequisites are met
