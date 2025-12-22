#!/bin/bash

# Kindura AI - Start Flutter App + Apple Watch
# This script starts the Flutter mobile app and Apple Watch simulator

echo "📱 Starting Kindura Flutter App + Apple Watch..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check Flutter installation
echo "🔍 Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter."
    exit 1
fi

# Open iOS Simulator
echo "📱 Opening iOS Simulator..."
open -a Simulator

# Wait for simulator to be ready
echo "⏳ Waiting for iOS Simulator to start..."
sleep 8

# Build and install watchOS app
echo "⌚ Building Apple Watch app..."
cd "$SCRIPT_DIR/flutter/watchos"

if [ -d "KinduraWatch.xcodeproj" ]; then
    # Clean and build the watchOS app
    xcodebuild -project KinduraWatch.xcodeproj \
        -scheme KinduraWatch \
        -sdk watchsimulator \
        -configuration Debug \
        -derivedDataPath build \
        clean build 2>&1 | grep -E "(BUILD|error:|warning:|\*\*)" || true

    # Check build result
    if [ -f "build/Build/Products/Debug-watchsimulator/KinduraWatch.app/KinduraWatch" ]; then
        echo "✅ watchOS app built successfully"

        # Find the built app
        WATCH_APP="build/Build/Products/Debug-watchsimulator/KinduraWatch.app"

        # Get available Watch simulators
        echo "🔍 Looking for Apple Watch simulator..."
        
        # First try to find a booted watch
        WATCH_UDID=$(xcrun simctl list devices available | grep -i "Apple Watch" | grep -i "Booted" | head -1 | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
        
        # If no booted watch, get first available
        if [ -z "$WATCH_UDID" ]; then
            WATCH_UDID=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}')
        fi

        if [ -n "$WATCH_UDID" ]; then
            echo "📲 Found Watch simulator: $WATCH_UDID"
            
            # Boot the Watch simulator if not already booted
            echo "🔄 Booting Watch simulator..."
            xcrun simctl boot "$WATCH_UDID" 2>/dev/null || echo "   (Already booted)"
            sleep 3

            # Install the app
            echo "📥 Installing KinduraWatch..."
            if xcrun simctl install "$WATCH_UDID" "$WATCH_APP"; then
                echo "✅ App installed successfully"

                # Launch the app
                echo "🚀 Launching KinduraWatch..."
                xcrun simctl launch "$WATCH_UDID" com.kindura.ai.watchkitapp 2>/dev/null || echo "   (Launch manually from Watch)"
                echo "✅ KinduraWatch ready!"
            else
                echo "❌ Failed to install app"
            fi
        else
            echo "⚠️  No Apple Watch simulator found"
            echo ""
            echo "💡 To add a Watch simulator:"
            echo "   1. Open Xcode → Window → Devices and Simulators"
            echo "   2. Click '+' at bottom left"
            echo "   3. Select 'Apple Watch Series 9' or similar"
            echo ""
            echo "Available simulators:"
            xcrun simctl list devices available | grep -i watch || echo "   None found"
        fi
    else
        echo "❌ watchOS app build failed"
        echo "💡 Try opening in Xcode: open flutter/watchos/KinduraWatch.xcodeproj"
    fi
else
    echo "⚠️  watchOS project not found"
fi

# Navigate to Flutter directory
cd "$SCRIPT_DIR/flutter"

# Get Flutter dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check for available devices
echo ""
echo "📱 Available devices:"
flutter devices

# Run Flutter app
echo ""
echo "🚀 Starting Flutter app..."
flutter run

echo ""
echo "🎉 Setup complete!"
echo ""
echo "⌚ Watch Controls:"
echo "   • Swipe left/right to switch tabs (Vitals, Sleep, Fall Detection)"
echo "   • Watch should sync with iPhone simulator automatically"
echo ""
echo "📱 Flutter Controls:"
echo "   • Press 'r' for hot reload"
echo "   • Press 'R' for full restart"
echo "   • Press 'q' to quit"
