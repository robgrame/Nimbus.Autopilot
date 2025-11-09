# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY Nimbus.Autopilot.Api/Nimbus.Autopilot.Api.csproj Nimbus.Autopilot.Api/
RUN dotnet restore "Nimbus.Autopilot.Api/Nimbus.Autopilot.Api.csproj"

# Copy everything else and build
COPY Nimbus.Autopilot.Api/ Nimbus.Autopilot.Api/
WORKDIR "/src/Nimbus.Autopilot.Api"
RUN dotnet build "Nimbus.Autopilot.Api.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "Nimbus.Autopilot.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 5000
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Nimbus.Autopilot.Api.dll"]
