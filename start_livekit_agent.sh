#!/bin/bash

# Start the LiveKit Agent

echo "Starting Kindura LiveKit Agent..."

# Navigate to LiveKit agent directory
cd /Users/ralabaji/Kinduraios/kinduralivekit-0.0.1

# Activate virtual environment
source venv/bin/activate

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found in kinduralivekit-0.0.1 directory"
    echo "Please ensure .env file exists with proper configuration"
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
python agent.py