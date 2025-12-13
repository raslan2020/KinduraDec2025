#!/bin/bash

# Start all Kindura services

echo "========================================="
echo "Starting all Kindura services..."
echo "========================================="

# Function to kill services on exit
cleanup() {
    echo ""
    echo "Stopping all services..."
    kill $DJANGO_PID $LIVEKIT_PID 2>/dev/null
    exit
}

# Set up trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start Django API server in background
echo ""
echo "1. Starting Django API Server..."
echo "---------------------------------"
./start_django.sh &
DJANGO_PID=$!

# Wait for Django to start
echo "Waiting for Django to start..."
sleep 5

# Check if Django is running
if ! curl -s http://localhost:8000/api > /dev/null; then
    echo "Warning: Django server might not be running properly"
else
    echo "Django server is running on http://localhost:8000"
fi

# Start LiveKit agent in background
echo ""
echo "2. Starting LiveKit Agent..."
echo "---------------------------------"
./start_livekit_agent.sh &
LIVEKIT_PID=$!

echo ""
echo "========================================="
echo "All services started!"
echo "========================================="
echo ""
echo "Services running:"
echo "- Django API: http://localhost:8000"
echo "- Django Admin: http://localhost:8000/admin (user: admin, pass: admin123)"
echo "- LiveKit Agent: Running in background"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Keep script running
wait