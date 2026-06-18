# BOC - Business Operations Center

A Flutter-based business operations management system with a Dart backend and PostgreSQL database.

## Architecture

- **Frontend**: Flutter (Web, iOS, Android, Windows, macOS)
- **Backend**: Dart with Shelf framework
- **Database**: PostgreSQL
- **Deployment**: Docker + Railway (or other cloud services)

## Prerequisites

- Flutter SDK (for development)
- Dart SDK (for backend development)
- Docker & Docker Compose (for deployment)
- PostgreSQL (if running without Docker)

## Local Development Setup

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd boc
```

### 2. Copy Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` with your local settings if needed.

### 3. Start Backend with Docker

```bash
docker-compose up -d
```

This will:
- Start PostgreSQL on port 5432
- Build and run the backend on port 8081
- Initialize the database

### 4. Run Frontend (Flutter)

#### Web Version
```bash
flutter run -d chrome
```

#### Mobile Version (iOS)
```bash
flutter run -d <device-id>
```

#### Desktop Version (Windows/macOS/Linux)
```bash
flutter run -d windows
# or
flutter run -d macos
# or
flutter run -d linux
```

## Backend API

The backend API server runs on `http://localhost:8081` by default.

**Key Endpoints:**
- `POST /api/auth/login` - User authentication
- `GET /api/raw-materials` - List raw materials
- `POST /api/raw-materials` - Create raw material
- etc.

## Configuration

### Environment Variables

All configuration is done through environment variables or `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 8081 | Backend server port |
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | postgres | Database name |
| `DB_USERNAME` | postgres | Database user |
| `DB_PASSWORD` | postgres | Database password |
| `DB_SSL_MODE` | disable | SSL mode (disable/prefer/require) |

### Frontend API Configuration

Edit `lib/services/api_base_url.dart` to change the backend URL:

```dart
const String BACKEND_HOST = 'localhost';
const int BACKEND_PORT = 8081;
```

For production:
```dart
const String BACKEND_HOST = 'your-production-domain.com';
const int BACKEND_PORT = 80;
```

## Deployment

### Docker Build

```bash
# Build the backend Docker image
docker build -t boc-backend .

# Run with custom environment
docker run -e DB_HOST=your-db-host \
           -e DB_USERNAME=your-user \
           -e DB_PASSWORD=your-pass \
           -p 8081:8081 \
           boc-backend
```

### Railway Deployment

1. Create a Railway account (https://railway.app)
2. Connect your GitHub repository
3. Create a new project from your repo
4. Configure environment variables:
   - `DB_HOST`: Your Railway PostgreSQL host
   - `DB_USERNAME`: PostgreSQL username
   - `DB_PASSWORD`: PostgreSQL password
   - `DB_NAME`: Database name
   - `DB_PORT`: Usually 5432
   - `DB_SSL_MODE`: Set to `require` for Railway
   - `PORT`: Your desired port (usually auto-configured)

5. Railway will automatically:
   - Detect the Dockerfile
   - Build and deploy the backend
   - Assign a public URL

### Frontend Deployment (Web)

#### GitHub Pages (Free)

1. Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build web --release
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

2. Update frontend API URL in GitHub Actions or use environment-based configuration
3. Push to GitHub and GitHub Pages will auto-deploy

#### Vercel (Alternative)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel
```

## Database Setup

The database schema is automatically created on first run. No manual setup needed.

### Available Tables

- `users` - User accounts and authentication
- `raw_materials` - Raw material inventory
- `raw_material_categories` - Material categories
- `raw_material_locations` - Storage locations
- (and more based on business logic)

## Troubleshooting

### Backend won't connect to database

```bash
# Check database is running
docker-compose ps

# Check logs
docker-compose logs postgres
docker-compose logs backend
```

### Frontend can't reach backend

1. Ensure backend is running: `curl http://localhost:8081`
2. Check API URL in `lib/services/api_base_url.dart`
3. On mobile: use your machine's IP instead of localhost
4. On web: backend must be on same domain or CORS must be enabled

### Docker build fails

```bash
# Clean and rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up
```

## Development Guidelines

- **Backend changes**: Modify `backend/bin/server.dart` and hot-reload the container
- **Frontend changes**: Use `flutter hot reload` (R) or `flutter hot restart` (Shift+R)
- **Database changes**: Edit schema creation in `initDb()` function
- **New API endpoints**: Add routes in the `_router` definition

## File Structure

```
.
├── backend/              # Dart backend server
│   ├── bin/
│   │   └── server.dart   # Main server file
│   └── pubspec.yaml
├── lib/                  # Flutter frontend
│   ├── main.dart
│   ├── pages/            # UI pages
│   ├── services/         # Business logic & API calls
│   └── ...
├── web/                  # Web build output
├── Dockerfile            # Backend container config
├── docker-compose.yaml   # Local dev environment
├── .env.example          # Environment variables template
└── README.md             # This file
```

## License

Proprietary - All rights reserved

## Support

For issues and questions, please open a GitHub issue.
