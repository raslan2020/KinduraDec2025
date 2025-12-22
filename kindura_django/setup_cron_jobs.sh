#!/bin/bash

# Kindura AI - Cron Job Setup Script
# This script sets up automated report generation

echo "🔧 Setting up Kindura cron jobs..."

# Get the absolute path to the project
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="${PROJECT_DIR}/../.venv/bin/python"
MANAGE_PY="${PROJECT_DIR}/manage.py"

# Verify paths exist
if [ ! -f "$VENV_PYTHON" ]; then
    echo "❌ Virtual environment Python not found at: $VENV_PYTHON"
    exit 1
fi

if [ ! -f "$MANAGE_PY" ]; then
    echo "❌ manage.py not found at: $MANAGE_PY"
    exit 1
fi

# Create log directory
mkdir -p "${PROJECT_DIR}/logs"

# Create cron job entries
CRON_JOBS="
# Kindura AI Report Generation Jobs
# Daily reports - run at 11:59 PM every day
59 23 * * * cd ${PROJECT_DIR} && ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type daily >> ${PROJECT_DIR}/logs/daily_reports.log 2>&1

# Weekly reports - run at 11:58 PM every Sunday
58 23 * * 0 cd ${PROJECT_DIR} && ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type weekly >> ${PROJECT_DIR}/logs/weekly_reports.log 2>&1

# Monthly reports - run at 11:57 PM on the 1st of each month
57 23 1 * * cd ${PROJECT_DIR} && ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type monthly >> ${PROJECT_DIR}/logs/monthly_reports.log 2>&1
"

echo "📋 Cron jobs to be installed:"
echo "$CRON_JOBS"
echo ""

# Check if user wants to install
read -p "Install these cron jobs? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup existing crontab
    crontab -l > /tmp/crontab_backup.txt 2>/dev/null || true

    # Check if Kindura jobs already exist
    if crontab -l 2>/dev/null | grep -q "Kindura AI Report Generation"; then
        echo "⚠️  Kindura cron jobs already exist. Removing old entries..."
        crontab -l 2>/dev/null | grep -v "Kindura AI\|generate_reports" > /tmp/crontab_new.txt || true
    else
        crontab -l > /tmp/crontab_new.txt 2>/dev/null || true
    fi

    # Add new jobs
    echo "$CRON_JOBS" >> /tmp/crontab_new.txt

    # Install new crontab
    crontab /tmp/crontab_new.txt

    echo "✅ Cron jobs installed successfully!"
    echo ""
    echo "📊 Current crontab:"
    crontab -l

    # Clean up
    rm -f /tmp/crontab_new.txt
else
    echo "❌ Cron job installation cancelled."
fi

echo ""
echo "📝 Manual commands:"
echo "  Generate daily report:   ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type daily"
echo "  Generate weekly report:  ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type weekly"
echo "  Generate monthly report: ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type monthly"
echo "  Generate all reports:    ${VENV_PYTHON} ${MANAGE_PY} generate_reports --type all"
echo ""
echo "📁 Logs will be saved to: ${PROJECT_DIR}/logs/"
