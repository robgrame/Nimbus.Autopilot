using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using Nimbus.Autopilot.Api.Data;
using Nimbus.Autopilot.Api.Middleware;
using Nimbus.Autopilot.Api.Hubs;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Authorization;

var builder = WebApplication.CreateBuilder(args);

// Add Entra AD authentication
builder.Services.AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection("AzureAd"));

// Add authorization with policies
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Administrator", policy =>
        policy.RequireRole("Administrator"));
});

// Add services to the container
builder.Services.AddControllersWithViews(options =>
    {
        // Require authentication for MVC controllers by default
        var policy = new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .Build();
        options.Filters.Add(new AuthorizeFilter(policy));
    })
    .AddMicrosoftIdentityUI()
    .AddNewtonsoftJson(options =>
    {
        // Use snake_case for JSON property names to match Python API
        options.SerializerSettings.ContractResolver = new DefaultContractResolver
        {
            NamingStrategy = new SnakeCaseNamingStrategy()
        };
        options.SerializerSettings.NullValueHandling = NullValueHandling.Ignore;
        options.SerializerSettings.DateTimeZoneHandling = DateTimeZoneHandling.Utc;
    });

// Add Razor Pages support
builder.Services.AddRazorPages()
    .AddMicrosoftIdentityUI();

// Configure database
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<NimbusDbContext>(options =>
    options.UseSqlServer(connectionString));

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:3000", "http://localhost:5000", "https://localhost:5001")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

// Add SignalR
builder.Services.AddSignalR();

// Add Swagger/OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Enable CORS
app.UseCors();

// Use API Key authentication middleware
app.UseMiddleware<ApiKeyAuthenticationMiddleware>();

app.UseHttpsRedirection();

// Serve static files for MVC/Razor Pages
app.UseStaticFiles();

app.UseRouting();

// Enable authentication and authorization
app.UseAuthentication();
app.UseAuthorization();

// Map SignalR hub
app.MapHub<TelemetryHub>("/hubs/telemetry");

app.MapControllers();

// Map default MVC route and Razor Pages
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");
app.MapRazorPages();

app.Run();
