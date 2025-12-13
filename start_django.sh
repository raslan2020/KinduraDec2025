#!/bin/bash

# Start the Django API server

echo "Starting Kindura Django API Server..."

# Navigate to Django project directory
cd /Users/ralabaji/Kinduraios/KinduraAPIs-0.0.1

# Activate virtual environment
source venv/bin/activate

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found in KinduraAPIs-0.0.1 directory"
    echo "Please ensure .env file exists with proper configuration"
    exit 1
fi

# Apply any pending migrations
echo "Applying database migrations..."
python manage.py migrate

# Start the Django development server
echo "Starting Django server on http://localhost:8000"
python manage.py runserver 0.0.0.0:8000