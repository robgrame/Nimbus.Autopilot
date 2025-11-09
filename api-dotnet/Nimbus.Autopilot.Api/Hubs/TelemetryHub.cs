using Microsoft.AspNetCore.SignalR;

namespace Nimbus.Autopilot.Api.Hubs;

public class TelemetryHub : Hub
{
    public async Task SendTelemetryUpdate(object telemetryData)
    {
        await Clients.All.SendAsync("ReceiveTelemetryUpdate", telemetryData);
    }

    public async Task JoinGroup(string groupName)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
    }

    public async Task LeaveGroup(string groupName)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);
    }
}
