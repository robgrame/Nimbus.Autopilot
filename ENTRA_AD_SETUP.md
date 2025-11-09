# Entra AD Authentication Setup Guide

This guide explains how to configure Microsoft Entra ID (Azure Active Directory) authentication for the Nimbus Autopilot monitoring dashboard.

## Overview

The Nimbus Autopilot monitoring dashboard now supports Entra AD authentication with role-based access control. Only users with the **Administrator** role can access the monitoring dashboard at `/Home/Dashboard`.

## Prerequisites

- Azure subscription with Entra ID (Azure AD)
- Administrative access to your Azure tenant
- .NET 8.0 SDK
- SQL Server database

## Step 1: Register the Application in Azure Portal

1. Sign in to the [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** (formerly Azure Active Directory)
3. Select **App registrations** → **New registration**
4. Configure the application:
   - **Name**: `Nimbus Autopilot Dashboard`
   - **Supported account types**: Select based on your organization's needs (typically "Accounts in this organizational directory only")
   - **Redirect URI**: 
     - Platform: `Web`
     - URI: `https://your-domain.com/signin-oidc` (update with your actual domain)
   - Click **Register**

5. After registration, note down the following values (you'll need them for configuration):
   - **Application (client) ID**
   - **Directory (tenant) ID**

## Step 2: Configure Authentication

1. In your app registration, go to **Authentication**
2. Under **Front-channel logout URL**, add: `https://your-domain.com/signout-oidc`
3. Under **Implicit grant and hybrid flows**, enable:
   - ✅ **ID tokens** (used for implicit and hybrid flows)
4. Click **Save**

## Step 3: Create a Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add a description (e.g., "Nimbus Dashboard Secret")
4. Select an expiration period
5. Click **Add**
6. **Important**: Copy the secret value immediately - you won't be able to see it again!

## Step 4: Configure App Roles

1. In your app registration, go to **App roles**
2. Click **Create app role**
3. Configure the Administrator role:
   - **Display name**: `Administrator`
   - **Allowed member types**: `Users/Groups`
   - **Value**: `Administrator`
   - **Description**: `Administrators have full access to the monitoring dashboard`
   - **Enable this app role**: ✅
4. Click **Apply**

## Step 5: Assign Users to the Administrator Role

1. Navigate to **Enterprise applications** in Entra ID
2. Find and select **Nimbus Autopilot Dashboard**
3. Go to **Users and groups**
4. Click **Add user/group**
5. Select users who should have administrator access
6. Under **Select a role**, choose **Administrator**
7. Click **Assign**

## Step 6: Update Application Configuration

Update the `appsettings.json` file in the API project with your Azure AD details:

```json
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "Domain": "yourdomain.onmicrosoft.com",
    "TenantId": "your-tenant-id-here",
    "ClientId": "your-client-id-here",
    "ClientSecret": "your-client-secret-here",
    "CallbackPath": "/signin-oidc",
    "SignedOutCallbackPath": "/signout-oidc"
  }
}
```

Replace the placeholder values:
- `your-tenant-id-here`: Directory (tenant) ID from Step 1
- `your-client-id-here`: Application (client) ID from Step 1
- `your-client-secret-here`: Client secret value from Step 3
- `yourdomain.onmicrosoft.com`: Your Azure AD domain

### Using Environment Variables (Recommended for Production)

For production deployments, use environment variables or Azure Key Vault instead of storing secrets in appsettings.json:

```bash
export AzureAd__TenantId="your-tenant-id"
export AzureAd__ClientId="your-client-id"
export AzureAd__ClientSecret="your-client-secret"
export AzureAd__Domain="yourdomain.onmicrosoft.com"
```

## Step 7: Update CORS Settings (if needed)

If your dashboard is hosted on a different domain, update the CORS policy in `Program.cs`:

```csharp
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("https://your-dashboard-domain.com")
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});
```

## Testing the Configuration

1. Start the application:
   ```bash
   cd api-dotnet/Nimbus.Autopilot.Api
   dotnet run
   ```

2. Navigate to `https://localhost:5001/Home/Dashboard`
3. You should be redirected to the Microsoft login page
4. Sign in with a user account that has been assigned the Administrator role
5. After successful authentication, you should be redirected back to the dashboard

## Authentication Flow

### For Dashboard Access
- Users accessing `/Home/Dashboard` must authenticate via Entra AD
- Only users with the **Administrator** role can access the dashboard
- Users without the role will receive an Access Denied error

### For API Endpoints
- API endpoints (`/api/*`) continue to use API key authentication
- This allows telemetry clients to submit data without Entra AD authentication
- Authenticated Entra AD users can also access API endpoints

## Troubleshooting

### Redirect URI Mismatch
**Error**: "AADSTS50011: The redirect URI specified in the request does not match..."

**Solution**: Ensure the redirect URI in Azure matches exactly what's configured in your application (including trailing slashes and protocol).

### Invalid Client Secret
**Error**: "AADSTS7000215: Invalid client secret..."

**Solution**: Verify the client secret is correct and hasn't expired. Create a new secret if needed.

### User Not in Administrator Role
**Error**: "Access Denied" or HTTP 403

**Solution**: Verify the user has been assigned the Administrator role in Enterprise Applications.

### Cannot Access API Endpoints
**Error**: HTTP 401 Unauthorized

**Solution**: Ensure you're sending the API key in the `X-API-Key` header for API calls from telemetry clients.

## Security Best Practices

1. **Never commit secrets**: Don't store client secrets in source control
2. **Use Key Vault**: For production, store secrets in Azure Key Vault
3. **Rotate secrets regularly**: Set up a process to rotate client secrets periodically
4. **Enable MFA**: Require multi-factor authentication for all administrator accounts
5. **Monitor sign-ins**: Enable sign-in logs and alerts in Azure AD
6. **Use managed identities**: When running on Azure, use managed identities instead of client secrets

## Additional Resources

- [Microsoft Identity Platform Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
- [Microsoft.Identity.Web Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/microsoft-identity-web)
- [Azure AD App Roles](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-add-app-roles-in-azure-ad-apps)
