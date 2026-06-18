# Deployment Guide

This guide explains how to deploy the BOC application to Railway using Docker.

## Quick Start (Railway)

### 1. Create Railway Account

- Go to https://railway.app
- Sign up with GitHub (recommended)

### 2. Create New Project

- Click "New Project"
- Select "Deploy from GitHub repo"
- Connect your GitHub account if not already connected
- Select this repository

### 3. Configure Environment Variables

Railway will auto-detect the Dockerfile. Before deploying, set these environment variables in Railway dashboard:

**Database Configuration (if using Railway PostgreSQL):**
```
DB_HOST=<railway-postgres-host>
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=postgres
DB_PASSWORD=<strong-password>
DB_SSL_MODE=require
PORT=8081
```

Or create a PostgreSQL database in Railway first:
- Click "New" in Railway project
- Select "PostgreSQL"
- Railway will automatically set `DATABASE_URL`

### 4. Add PostgreSQL Service (Optional)

If Railway provided `DATABASE_URL`:
- Parse it: `postgresql://username:password@host:port/dbname`
- Set individual environment variables accordingly

### 5. Deploy

Railway will automatically:
- Detect the Dockerfile
- Build the Docker image
- Deploy the container
- Provide a public URL (e.g., `https://boc-backend-prod.up.railway.app`)

### 6. Update Frontend Configuration

Once backend is deployed, update the frontend API URL:

**Web Frontend (for GitHub Pages or Vercel):**

Edit `lib/services/api_base_url.dart`:
```dart
const String BACKEND_HOST = 'your-app.up.railway.app';
const int BACKEND_PORT = 80;
```

**Mobile App:**

The same configuration works, but ensure the URL is accessible from mobile networks.

## Docker Local Testing

Before deploying, test locally:

```bash
# Build the Docker image
docker build -t boc-backend:latest .

# Create .env file with your database credentials
cat > .env << EOF
PORT=8081
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_SSL_MODE=disable
EOF

# Run with docker-compose
docker-compose up -d

# Test the backend
curl http://localhost:8081

# View logs
docker-compose logs -f backend
```

## Troubleshooting

### Backend Build Fails on Railway

1. Check Railway deployment logs
2. Ensure `Dockerfile` exists in repo root
3. Verify `backend/pubspec.yaml` and `backend/pubspec.lock` exist
4. Try building locally: `docker build -t boc-backend .`

### Database Connection Errors

- Verify `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` are correct
- If using external database, ensure it's not behind a firewall
- Test connection locally first

### Frontend Can't Reach Backend

1. Update `BACKEND_HOST` in `lib/services/api_base_url.dart`
2. Ensure backend is publicly accessible
3. Check browser console for CORS errors
4. Verify backend `corsMiddleware()` is enabled

### Port Already in Use

Change the `PORT` environment variable:
```bash
PORT=3000 docker-compose up
```

## Advanced: Using Multiple Environments

Create separate environments for development and production:

### Development
```bash
# .env.development
DB_HOST=localhost
DB_PASSWORD=dev_password
PORT=8081
```

### Production
```bash
# Set in Railway dashboard
DB_HOST=production-db.example.com
DB_PASSWORD=<strong-production-password>
PORT=80
DB_SSL_MODE=require
```

### Load .env file

```bash
# Load from .env.development
set -a
source .env.development
set +a
docker-compose up
```

## Monitoring

### Railway Dashboard

- View logs in real-time
- Monitor CPU/Memory usage
- Check deployment history

### Backend Logs

```bash
# Local
docker-compose logs -f backend

# Railway (via CLI)
railway logs
```

## Rollback

If deployment fails:

1. Railway keeps previous builds
2. Click "Rollback" in Railway dashboard
3. Select previous working version
4. Deploy

## Cost Estimation

Railway pricing (as of 2024):
- $5/month free tier includes:
  - ~100 hours of compute
  - ~100 GB bandwidth
  - PostgreSQL database

For small projects, usually stays within free tier.

Excess usage: $0.000463/compute-second

## Next Steps

1. Deploy backend to Railway
2. Deploy frontend to GitHub Pages or Vercel
3. Monitor deployments and logs
4. Set up automated backups for database

See [README.md](./README.md) for more information.
