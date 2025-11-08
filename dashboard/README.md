# Nimbus Autopilot Dashboard

Web-based dashboard for monitoring Windows Autopilot deployment progress.

## Features

- **Real-time Monitoring**: Live updates of deployment progress
- **Interactive Dashboard**: Visual statistics and charts
- **Client Management**: View and filter client devices
- **Detailed Analytics**: Drill-down into individual client telemetry
- **Responsive Design**: Works on desktop and mobile devices

## Prerequisites

- Node.js 14+ and npm
- Running Nimbus API backend

## Installation

1. Install dependencies:
```bash
cd dashboard
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your API endpoint and key
```

3. Start development server:
```bash
npm start
```

The dashboard will open at `http://localhost:3000`.

## Building for Production

```bash
npm run build
```

This creates an optimized production build in the `build/` directory.

## Deployment

### Static Hosting (Netlify, Vercel, etc.)

1. Build the application
2. Deploy the `build/` directory
3. Configure environment variables in the hosting platform

### Docker Deployment

Create a `Dockerfile`:
```dockerfile
FROM node:18-alpine as build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Build and run:
```bash
docker build -t nimbus-dashboard .
docker run -p 80:80 nimbus-dashboard
```

## Dashboard Features

### Overview Tab
- Total clients count
- Active deployments
- Average deployment duration
- Status distribution chart

### Clients Tab
- List of all enrolled devices
- Filter by status (active, completed, failed)
- Search by client ID or device name
- Real-time updates (refreshes every 30 seconds)
- Sort capabilities
- View detailed client information

### Client Details Modal
- Device information
- Progress over time chart
- Complete telemetry event history
- Phase-by-phase breakdown

## Configuration

### Environment Variables

- `REACT_APP_API_URL`: Base URL of the Nimbus API (required)
- `REACT_APP_API_KEY`: API key for authentication (required)

### Polling Interval

The dashboard automatically refreshes data every 30 seconds. To change this, modify the interval in:
- `src/components/Dashboard.js`
- `src/components/ClientList.js`

## Development

### Project Structure

```
dashboard/
├── public/
│   └── index.html          # HTML template
├── src/
│   ├── components/
│   │   ├── Dashboard.js     # Statistics dashboard
│   │   ├── ClientList.js    # Client list view
│   │   └── ClientDetails.js # Client details modal
│   ├── services/
│   │   └── api.js          # API client
│   ├── App.js              # Main application
│   ├── App.css             # Styles
│   └── index.js            # Entry point
└── package.json
```

### Adding Features

To add new visualizations or features:

1. Create new component in `src/components/`
2. Import and use in `App.js`
3. Add API calls in `src/services/api.js` if needed
4. Update styles in `App.css`

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Troubleshooting

### Cannot connect to API

1. Verify API is running: `curl http://localhost:5000/api/health`
2. Check CORS settings in API
3. Verify environment variables in `.env`
4. Check browser console for errors

### Data not updating

1. Check network tab in browser DevTools
2. Verify API key is correct
3. Check API logs for errors
4. Ensure API endpoints are accessible

### Build errors

1. Delete `node_modules` and `package-lock.json`
2. Run `npm install` again
3. Clear npm cache: `npm cache clean --force`

## Performance

- Automatic data refresh every 30 seconds
- Optimized chart rendering with Chart.js
- Responsive design for various screen sizes
- Minimal re-renders with React best practices

## Security

- API key stored in environment variables
- HTTPS recommended for production
- No sensitive data in client-side code
- Secure communication with backend API
