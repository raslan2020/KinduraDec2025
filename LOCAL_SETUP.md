# Kindura AI Local Development Setup

This guide explains how to run the Kindura AI application locally on your machine.

## System Requirements

- Python 3.11 or higher
- Flutter 3.32+
- macOS/Linux/Windows
- 8GB RAM minimum
- Active internet connection (for LiveKit cloud)

## Architecture Overview

The Kindura AI system consists of three main components:

1. **Flutter Mobile App** - iOS/Android client application
2. **Django API Server** - Backend REST API (port 8000)
3. **LiveKit Agent** - Real-time voice AI agent

## Initial Setup Completed

The following has been configured for local development:

### 1. Environment Files Created

- **KinduraAPIs-0.0.1/.env** - Django configuration
- **kinduralivekit-0.0.1/.env** - LiveKit agent configuration

### 2. Database Setup

- SQLite database created and migrated
- Admin user created: `admin` / `admin123`

### 3. Dependencies Installed

- Django API dependencies in `KinduraAPIs-0.0.1/venv`
- LiveKit agent dependencies in `kinduralivekit-0.0.1/venv`

### 4. API Endpoints Updated

- Flutter app configured to use `http://localhost:8000/api`

## Required API Keys

Before running the LiveKit agent, you need to add your API keys to `kinduralivekit-0.0.1/.env`:

```bash
# Edit the .env file
cd kinduralivekit-0.0.1
nano .env

# Add your keys:
OPENAI_API_KEY=your_actual_openai_key_here
DEEPGRAM_API_KEY=your_actual_deepgram_key_here
```

## Running the Services

### Option 1: Run All Services Together

```bash
cd /Users/ralabaji/Kinduraios
./start_all_services.sh
```

This will start both the Django API server and LiveKit agent. Press `Ctrl+C` to stop all services.

### Option 2: Run Services Individually

#### Start Django API Server
```bash
cd /Users/ralabaji/Kinduraios
./start_django.sh
```
Access at: http://localhost:8000

#### Start LiveKit Agent
```bash
cd /Users/ralabaji/Kinduraios
./start_livekit_agent.sh
```

### Option 3: Manual Start

#### Django API Server
```bash
cd KinduraAPIs-0.0.1
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

#### LiveKit Agent
```bash
cd kinduralivekit-0.0.1
source venv/bin/activate
python agent.py
```

## Running the Flutter App

### iOS (macOS only)
```bash
flutter run -d ios
```

### Android
```bash
flutter run -d android
```

### Web (not recommended for voice features)
```bash
flutter run -d chrome
```

## Accessing Services

- **Django API**: http://localhost:8000/api
- **Django Admin**: http://localhost:8000/admin
  - Username: `admin`
  - Password: `admin123`
- **Flutter App**: Running on your device/emulator

## Testing the Setup

1. Start all services using `./start_all_services.sh`
2. Open the Flutter app on your device
3. Create a new account or login with test credentials
4. Test voice activation by saying "Hey Kindura"
5. The app should connect to the local LiveKit agent

## Troubleshooting

### Port Already in Use
If port 8000 is already in use:
```bash
# Find and kill the process
lsof -i :8000
kill -9 <PID>
```

### Database Issues
Reset the database:
```bash
cd KinduraAPIs-0.0.1
rm db.sqlite3
source venv/bin/activate
python manage.py migrate
python manage.py createsuperuser
```

### LiveKit Connection Issues
- Ensure you have valid API keys in the `.env` file
- Check that the Django server is running
- Verify the LiveKit URL in both `.env` files

### Flutter App Can't Connect
- For iOS Simulator: Use `http://localhost:8000/api`
- For Android Emulator: Use `http://10.0.2.2:8000/api`
- For Physical Device: Use your machine's IP address

## Environment Variables Reference

### Django (.env)
```
SECRET_KEY=<django-secret-key>
DEBUG=True
LIVEKIT_URL=wss://kindura-u99yilqz.livekit.cloud
LIVEKIT_API_KEY=APImEMbwqie8wdf
LIVEKIT_API_SECRET=<livekit-secret>
OPENAI_API_KEY=<openai-key>
```

### LiveKit Agent (.env)
```
LIVEKIT_URL=wss://kindura-u99yilqz.livekit.cloud
LIVEKIT_API_KEY=APImEMbwqie8wdf
LIVEKIT_API_SECRET=<livekit-secret>
OPENAI_API_KEY=<openai-key>
DEEPGRAM_API_KEY=<deepgram-key>
API_BASE_URL=http://localhost:8000/api
```

## Development Workflow

1. Make changes to the code
2. For Django changes: Server auto-reloads
3. For LiveKit agent changes: Restart the agent
4. For Flutter changes: Hot reload with `r` or restart with `R`

## Production Deployment

To deploy to production:

1. Update API URLs in `lib/res/app_url/app_url.dart` back to production server
2. Update `.env` files with production credentials
3. Set `DEBUG=False` in Django settings
4. Use proper database (PostgreSQL recommended)
5. Deploy using appropriate production servers (Gunicorn, Nginx, etc.)

## Support

For issues or questions:
- Check the logs in terminal windows
- Review the CLAUDE.md file for project structure
- Ensure all dependencies are installed correctly
- Verify API keys are valid and properly configured