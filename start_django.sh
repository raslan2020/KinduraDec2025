#!/bin/bash

# Start the Django API server

echo "Starting Kindura Django API Server..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to Django project directory
cd "$SCRIPT_DIR/django"

# Activate virtual environment (try both locations)
if [ -d "../.venv" ]; then
    source ../.venv/bin/activate
elif [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "Error: Virtual environment not found"
    echo "Please create one with: python3 -m venv .venv (in project root)"
    exit 1
fi

# Check if .env file exists (optional for local dev)
if [ -f "../.env.local" ]; then
    export $(cat ../.env.local | grep -v '^#' | xargs)
    echo "Loaded environment from .env.local"
fi

# Apply any pending migrations
echo "Applying database migrations..."
python manage.py migrate

# Start the Django development server
echo "Starting Django server on http://localhost:8000"
python manage.py runserver 0.0.0.0:8000
