#!/bin/bash

# Start the LiveKit Agent

echo "Starting Kindura LiveKit Agent..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to LiveKit agent directory
cd "$SCRIPT_DIR/livekit"

# Activate virtual environment (try both locations)
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d "../.venv" ]; then
    source ../.venv/bin/activate
else
    echo "Error: Virtual environment not found"
    echo "Please create one with: python3 -m venv venv (in livekit/)"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found in livekit/ directory"
    echo "Please ensure .env file exists with proper configuration"
    echo ""
    echo "Required variables:"
    echo "  LIVEKIT_URL=wss://your-project.livekit.cloud"
    echo "  LIVEKIT_API_KEY=your_api_key"
    echo "  LIVEKIT_API_SECRET=your_api_secret"
    echo "  OPENAI_API_KEY=your_openai_key"
    echo "  DEEPGRAM_API_KEY=your_deepgram_key"
    exit 1
fi

# Check for required API keys
if ! grep -q "OPENAI_API_KEY=" .env || grep -q "OPENAI_API_KEY=your_openai_api_key_here" .env; then
    echo "Warning: OPENAI_API_KEY not configured in .env file"
    echo "Please add your OpenAI API key to the .env file"
fi

if ! grep -q "DEEPGRAM_API_KEY=" .env || grep -q "DEEPGRAM_API_KEY=your_deepgram_api_key_here" .env; then
    echo "Warning: DEEPGRAM_API_KEY not configured in .env file"
    echo "Please add your Deepgram API key to the .env file"
fi

# Start the LiveKit agent
echo "Starting LiveKit agent..."
python agent.py start
