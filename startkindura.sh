#!/bin/bash

# Kindura AI - Start All Services Script (Local Development)
# This script starts the Django API with PostgreSQL database, LiveKit agent, and Flutter app
#
# 📋 Local Development Setup:
# • Django API: Uses local PostgreSQL database (localhost:5432)
# • Flutter App: Configured to use localhost API (see app_url.dart)
# • File uploads: Stored locally in media/ folder
# • All data: Stays on your local machine for testing

echo "🚀 Starting Kindura AI Services (Local Development Mode)..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Kill any existing processes
echo "🔄 Stopping existing services..."
pkill -f "flutter run" 2>/dev/null || true
pkill -f "python agent.py" 2>/dev/null || true
pkill -f "python manage.py runserver" 2>/dev/null || true

# Kill any process using ports 8000, 3000, and 8081 (LiveKit agent)
echo "🔄 Freeing up ports 8000, 3000, 8081..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:8081 | xargs kill -9 2>/dev/null || true

# Check for Python virtual environments
echo "🔍 Checking Python environments..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python3."
    exit 1
fi

# Wait a moment for processes to clean up
sleep 3

# Check and start PostgreSQL
echo "🐘 Checking PostgreSQL service..."
if brew services list | grep postgresql@15 | grep -q started; then
    echo "✅ PostgreSQL is running"
else
    echo "🔄 Starting PostgreSQL service..."
    brew services start postgresql@15
    echo "⏳ Waiting for PostgreSQL to start..."
    sleep 3
    echo "✅ PostgreSQL started"
fi

# Verify PostgreSQL connection
echo "🔍 Testing PostgreSQL connection..."
if /opt/homebrew/opt/postgresql@15/bin/psql -d kindura_db -c "SELECT 1" >/dev/null 2>&1; then
    echo "✅ PostgreSQL database 'kindura_db' is accessible"
else
    echo "⚠️  Warning: Cannot connect to PostgreSQL database"
    echo "💡 Run './setup_local.sh' to set up the database"
fi

echo "⚙️  Starting Django API Server in new terminal..."
cd "$SCRIPT_DIR"
if [ -d ".venv" ]; then
    # Check if requirements are met
    if [ -f "requirements.txt" ]; then
        echo "🔍 Checking Django dependencies..."
        source .venv/bin/activate
        pip install -r requirements.txt --quiet
        deactivate
    fi

    # Run Django migrations if needed
    echo "🔄 Running Django migrations..."
    source .venv/bin/activate
    cd KinduraAPIs-0.0.1
    python manage.py migrate --no-input
    cd ..
    deactivate

    # Start Django server in new terminal
    # Use 0.0.0.0 to allow connections from Watch simulator
    osascript -e "tell application \"Terminal\" to do script \"cd '$SCRIPT_DIR/KinduraAPIs-0.0.1' && source ../.venv/bin/activate && echo '🚀 Django API Server Starting (PostgreSQL Database)...' && python manage.py runserver 0.0.0.0:8000\""
    echo "✅ Django API started in new Terminal tab (PostgreSQL)"
    sleep 3  # Give it time to start
else
    echo "❌ Django .venv not found in project root/"
    echo "💡 Run: python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

echo "🎤 Starting LiveKit Agent in new terminal..."
cd "$SCRIPT_DIR/kinduralivekit-0.0.1"
if [ -d "venv" ]; then
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        echo "⚠️  .env file not found in kinduralivekit-0.0.1/"
        echo "💡 Create .env with LIVEKIT_API_KEY, LIVEKIT_API_SECRET, etc."
    fi
    
    # Check if requirements are met
    if [ -f "requirements.txt" ]; then
        echo "🔍 Checking LiveKit dependencies..."
        source venv/bin/activate
        pip install -r requirements.txt --quiet
        deactivate
    fi
    
    # Check agent.py syntax before starting
    echo "🔍 Checking agent.py syntax..."
    source venv/bin/activate
    if ! python -m py_compile agent.py; then
        echo "❌ agent.py has syntax errors - fix them first"
        deactivate
        exit 1
    fi
    deactivate
    
    # Start LiveKit agent in new terminal
    echo "🚀 Starting LiveKit agent in new Terminal tab..."
    osascript -e "tell application \"Terminal\" to do script \"cd '$SCRIPT_DIR/kinduralivekit-0.0.1' && source venv/bin/activate && echo '🎤 LiveKit Agent Starting...' && python agent.py start\""
    echo "✅ LiveKit Agent started in new Terminal tab"
    sleep 3  # Give it time to start
else
    echo "❌ LiveKit venv not found in kinduralivekit-0.0.1/"
    echo "💡 Run: cd kinduralivekit-0.0.1 && python3 -m venv venv"
    exit 1
fi

# Wait for backend services to be ready
echo "⏳ Waiting for backend services to initialize..."
sleep 5

# Check backend health
echo "🔍 Checking Django API health..."
for i in {1..10}; do
    # Test basic connectivity - just check if port is open
    if nc -z 127.0.0.1 8000 2>/dev/null; then
        echo "✅ Django API is ready on port 8000 (PostgreSQL Database)"

        # Verify PostgreSQL connection by checking Django admin is accessible
        if curl -s "http://127.0.0.1:8000/admin/" | grep -q "Django" 2>/dev/null; then
            echo "💾 PostgreSQL database connectivity verified"
        fi
        break
    else
        echo "⏳ Waiting for Django API port... ($i/10)"
    fi
    sleep 2
    if [ $i -eq 10 ]; then
        echo "⚠️  Django API may not be fully ready, continuing anyway..."
    fi
done

echo "📱 Opening iOS Simulator..."
open -a Simulator

# Wait for simulator to be ready
echo "⏳ Waiting for iOS Simulator to be ready..."
sleep 10

# Build and install watchOS app
echo "⌚ Building and installing Apple Watch app..."
cd "$SCRIPT_DIR/watchos"
if [ -d "KinduraWatch.xcodeproj" ]; then
    echo "🔨 Building KinduraWatch..."

    # Clean and build the watchOS app
    xcodebuild -project KinduraWatch.xcodeproj \
        -scheme KinduraWatch \
        -sdk watchsimulator \
        -configuration Debug \
        -derivedDataPath build \
        clean build 2>&1 | tee /tmp/watch_build.log | grep -E "(BUILD|error:|warning:|\*\*)" || true

    # Check build result
    if grep -q "BUILD SUCCEEDED" /tmp/watch_build.log; then
        echo "✅ watchOS app built successfully"

        # Find the built app
        WATCH_APP=$(find build -name "KinduraWatch.app" -path "*Debug-watchsimulator*" -type d 2>/dev/null | head -1)

        if [ -n "$WATCH_APP" ]; then
            echo "📱 Found app at: $WATCH_APP"

            # Get available Watch simulators (prefer booted one)
            echo "🔍 Looking for Apple Watch simulator..."
            WATCH_UDID=$(xcrun simctl list devices available | grep -i "Apple Watch" | grep -i "Booted" | head -1 | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
            # If no booted watch, get first available
            if [ -z "$WATCH_UDID" ]; then
                WATCH_UDID=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
            fi

            if [ -n "$WATCH_UDID" ]; then
                echo "📲 Installing on Watch simulator ($WATCH_UDID)..."

                # Boot the Watch simulator if not already booted
                xcrun simctl boot "$WATCH_UDID" 2>/dev/null || true
                sleep 2

                # Install the app
                if xcrun simctl install "$WATCH_UDID" "$WATCH_APP"; then
                    echo "✅ App installed successfully"

                    # Launch the app
                    if xcrun simctl launch "$WATCH_UDID" com.kindura.ai.watchkitapp; then
                        echo "✅ KinduraWatch launched on Watch simulator"
                    else
                        echo "⚠️  Failed to launch app (may need manual launch)"
                    fi
                else
                    echo "❌ Failed to install app on Watch simulator"
                fi
            else
                echo "⚠️  No Apple Watch simulator found"
                echo "💡 Add a Watch simulator in Xcode > Window > Devices and Simulators"
                echo "Available simulators:"
                xcrun simctl list devices available | grep -i watch || echo "None found"
            fi
        else
            echo "❌ Built app not found in expected location"
            echo "Searching for .app files..."
            find build -name "*.app" -type d 2>/dev/null
        fi
    else
        echo "❌ watchOS app build FAILED"
        echo "Check /tmp/watch_build.log for details"
        grep -A2 "error:" /tmp/watch_build.log || true
    fi
else
    echo "⚠️  watchOS project not found at watchos/KinduraWatch.xcodeproj"
fi
cd "$SCRIPT_DIR"

# Check Flutter installation
echo "🔍 Checking Flutter installation..."
cd "$SCRIPT_DIR"
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter."
    exit 1
fi

# Run Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Kill any existing Flutter processes first
echo "🔄 Stopping any existing Flutter apps..."
pkill -f "flutter run" 2>/dev/null || true
sleep 2

# Check if iPhone 16 is available
echo "📱 Checking for iPhone 16 simulator..."
if flutter devices | grep -q "iPhone 16"; then
    echo "✅ iPhone 16 simulator detected"
    echo "📱 Starting Flutter App on iPhone 16 (full restart)..."
    flutter run -d "iPhone 16" &
    FLUTTER_PID=$!
    echo "✅ Flutter App started (PID: $FLUTTER_PID)"
else
    echo "⚠️  iPhone 16 simulator not found, available devices:"
    flutter devices
    echo "🔄 Trying to run on any available iOS simulator..."
    flutter run -d ios &
    FLUTTER_PID=$!
    echo "✅ Flutter App started (PID: $FLUTTER_PID)"
fi

echo ""
echo "🎉 All Kindura AI services started successfully!"
echo ""
echo "📊 Services Running:"
echo "  PostgreSQL DB:  localhost:5432/kindura_db (kindura_user)"
echo "  Django API:     New Terminal Tab (http://127.0.0.1:8000)"
echo "  LiveKit Agent:  New Terminal Tab (wss://kindura-u99yilqz.livekit.cloud)"
echo "  Flutter App:    PID $FLUTTER_PID (Running on iOS Simulator)"
echo ""
echo "🌐 Services:"
echo "  Django API:     http://127.0.0.1:8000 (Local Development)"
echo "  LiveKit Agent:  wss://kindura-u99yilqz.livekit.cloud"
echo "  Flutter App:    Running on iOS Simulator"
echo ""
echo "🛑 To stop all services:"
echo "  • Close the Django and LiveKit Terminal tabs manually"
echo "  • Or use Ctrl+C in those terminals"
echo ""
echo "📱 Voice commands: 'hey kindura', 'i can do it', 'hey candura'"
echo ""
echo "🔄 Flutter Hot Restart:"
echo "  • Press 'r' in the Flutter terminal to hot restart"
echo "  • Press 'R' for full restart"
echo ""
echo "🔧 Troubleshooting:"
echo "  • If no audio: Test on physical device, not simulator"
echo "  • If agent doesn't respond: Check LiveKit agent logs above"
echo "  • If build fails: Run 'flutter clean && flutter pub get'"
echo "  • API not working: Check Django logs in the terminal tab"
echo "  • DB issues: Run 'python manage.py migrate' in the Django directory"
echo "  • Switch to production: Change 'isLocalEnvironment = false' in app_url.dart"
echo ""
echo "📊 Logs available at:"
echo "  • Django: Check terminal output above"
echo "  • LiveKit: Check terminal output above" 
echo "  • Flutter: Check terminal output above"

# Function to gracefully stop services
cleanup() {
    echo ""
    echo "🛑 Stopping all services..."

    # Kill Flutter app (we have its PID)
    [ ! -z "$FLUTTER_PID" ] && kill $FLUTTER_PID 2>/dev/null && echo "✅ Flutter App stopped"

    # Force kill any remaining processes (including those in separate terminals)
    pkill -f "python manage.py runserver" 2>/dev/null && echo "✅ Django stopped" || true
    pkill -f "python agent.py" 2>/dev/null && echo "✅ LiveKit Agent stopped" || true
    pkill -f "flutter run" 2>/dev/null || true

    # Also kill by port to ensure complete cleanup
    echo "🔄 Freeing up ports..."
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true  # Django
    lsof -ti:8081 | xargs kill -9 2>/dev/null || true  # LiveKit Agent

    echo "✅ All services stopped"
    echo "💡 Terminal tabs may remain open but processes are killed"
    exit 0
}

# Trap signals to cleanup properly
trap cleanup SIGINT SIGTERM

# Wait for user input to stop services
read -p "Press Enter to stop all services..."
cleanup