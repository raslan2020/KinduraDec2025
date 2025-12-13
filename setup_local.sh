#!/bin/bash

# Kindura AI - Local Development Setup Script
# Run this script once to set up the local development environment

echo "🔧 Setting up Kindura AI Local Development Environment..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📍 Current directory: $SCRIPT_DIR"

# Check if virtual environment exists
if [ ! -d ".venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv .venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment and install dependencies
echo "📦 Installing Python dependencies..."
source .venv/bin/activate

if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo "✅ Python dependencies installed"
else
    echo "⚠️  requirements.txt not found"
fi

# Check for PostgreSQL installation
echo "🐘 Checking PostgreSQL installation..."
if command -v psql &> /dev/null || [ -f "/opt/homebrew/bin/psql" ] || [ -f "/opt/homebrew/opt/postgresql@15/bin/psql" ]; then
    echo "✅ PostgreSQL is installed"
else
    echo "❌ PostgreSQL not found. Installing PostgreSQL@15..."
    brew install postgresql@15
    brew services start postgresql@15
    echo "✅ PostgreSQL installed and started"
fi

# Start PostgreSQL service if not running
echo "🔄 Ensuring PostgreSQL service is running..."
if brew services list | grep postgresql@15 | grep -q started; then
    echo "✅ PostgreSQL is already running"
else
    brew services start postgresql@15
    echo "✅ PostgreSQL service started"
    sleep 2  # Give PostgreSQL time to start
fi

# Setup PostgreSQL database
echo "🗃️  Setting up PostgreSQL database..."
DB_NAME="kindura_db"
DB_USER="kindura_user"
DB_PASS="kindura_pass"

# Check if database exists
if /opt/homebrew/opt/postgresql@15/bin/psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo "✅ Database '$DB_NAME' already exists"
else
    echo "📊 Creating database '$DB_NAME'..."
    /opt/homebrew/opt/postgresql@15/bin/createdb $DB_NAME
    echo "✅ Database created"
fi

# Check if user exists
if /opt/homebrew/opt/postgresql@15/bin/psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    echo "✅ User '$DB_USER' already exists"
else
    echo "👤 Creating database user '$DB_USER'..."
    /opt/homebrew/opt/postgresql@15/bin/psql -d $DB_NAME -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    echo "✅ User created"
fi

# Set user permissions
/opt/homebrew/opt/postgresql@15/bin/psql -d postgres -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;" 2>/dev/null
/opt/homebrew/opt/postgresql@15/bin/psql -d $DB_NAME -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';" 2>/dev/null
/opt/homebrew/opt/postgresql@15/bin/psql -d $DB_NAME -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';" 2>/dev/null
/opt/homebrew/opt/postgresql@15/bin/psql -d $DB_NAME -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';" 2>/dev/null
/opt/homebrew/opt/postgresql@15/bin/psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;" 2>/dev/null

# Navigate to Django directory
cd KinduraAPIs-0.0.1

# Run Django migrations
echo "🔄 Running Django migrations..."
python manage.py migrate --no-input
echo "✅ Database migrations completed"

# Return to root directory
cd ..

# Create test user for development
echo "👤 Creating test user for development..."
echo ""
read -p "Do you want to create a test user? (y/n): " create_user

if [[ "$create_user" == "y" || "$create_user" == "Y" ]]; then
    cd KinduraAPIs-0.0.1

    echo "Creating test user: test@kindura.com"
    python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
django.setup()

from users.models import User

# Create test user if doesn't exist
if not User.objects.filter(email='test@kindura.com').exists():
    user = User.objects.create_user(
        username='testuser',
        email='test@kindura.com',
        password='TestPass123',
        first_name='Test',
        last_name='User',
        gender='M'
    )
    # Get or create token
    from rest_framework.authtoken.models import Token
    token = Token.objects.get_or_create(user=user)[0]
    print(f'✅ Test user created successfully!')
    print(f'   Email: test@kindura.com')
    print(f'   Password: TestPass123')
    print(f'   Token: {token.key}')
else:
    print('✅ Test user already exists (test@kindura.com)')
    user = User.objects.get(email='test@kindura.com')
    from rest_framework.authtoken.models import Token
    token = Token.objects.get_or_create(user=user)[0]
    print(f'   Token: {token.key}')
" 2>/dev/null || echo "⚠️ Could not create test user automatically"

    cd ..
    echo ""
fi

# Generate .env.local file with authentication token
echo "📝 Generating .env.local configuration file..."
cd KinduraAPIs-0.0.1

# Get the token from database
LOCAL_TOKEN=$(python -c "
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
django.setup()

from users.models import User, UserToken

try:
    user = User.objects.get(email='test@kindura.com')
    token = UserToken.objects.filter(user=user, is_active=True).first()
    if token:
        print(token.token)
    else:
        print('NO_TOKEN_FOUND')
except:
    print('NO_USER_FOUND')
" 2>/dev/null)

cd ..

if [[ "$LOCAL_TOKEN" != "NO_TOKEN_FOUND" && "$LOCAL_TOKEN" != "NO_USER_FOUND" && ! -z "$LOCAL_TOKEN" ]]; then
    # Create .env.local file
    cat > .env.local << EOF
# Local Development Environment Variables
# This file is auto-generated by setup_local.sh
# DO NOT commit this file to git

# PostgreSQL Database
DB_NAME=kindura_db
DB_USER=kindura_user
DB_PASSWORD=kindura_pass
DB_HOST=localhost
DB_PORT=5432

# Local Development Authentication Token
# Generated from test user: test@kindura.com
LOCAL_DEV_TOKEN=$LOCAL_TOKEN

# API Configuration
API_BASE_URL=http://127.0.0.1:8000/api
EOF

    echo "✅ Created .env.local with authentication token"
    echo "   Token: $LOCAL_TOKEN"
else
    echo "⚠️ Could not generate .env.local - no valid token found"
    echo "   You may need to create a test user first"
fi

echo ""

# Create superuser if needed (optional)
echo "👤 Creating admin user (optional)..."
echo "If you want to access Django admin panel at http://127.0.0.1:8000/admin/"
echo "You can create a superuser by running:"
echo "  cd KinduraAPIs-0.0.1 && ../.venv/bin/python manage.py createsuperuser"
echo ""

# Check Flutter dependencies
echo "📱 Checking Flutter dependencies..."
if command -v flutter &> /dev/null; then
    flutter pub get
    echo "✅ Flutter dependencies installed"
else
    echo "⚠️  Flutter not found. Please install Flutter from https://flutter.dev"
fi

deactivate

echo ""
echo "🎉 Local development environment setup complete!"
echo ""
echo "📋 What was set up:"
echo "  • Python virtual environment (.venv)"
echo "  • PostgreSQL database (kindura_db)"
echo "  • Django dependencies installed"
echo "  • Database migrations applied"
echo "  • Flutter dependencies installed"
echo ""
echo "🚀 To start all services:"
echo "  ./startkindura.sh"
echo ""
echo "🔧 Configuration:"
echo "  • API URL: Configured for localhost (see lib/res/app_url/app_url.dart)"
echo "  • Database: PostgreSQL (localhost:5432/kindura_db)"
echo "  • DB User: kindura_user / kindura_pass"
echo "  • File uploads: Stored locally in media/ folder"
echo ""
if [[ "$create_user" == "y" || "$create_user" == "Y" ]]; then
echo "🔑 Test User Credentials:"
echo "  • Email: test@kindura.com"
echo "  • Password: TestPass123"
echo ""
fi
echo "💡 Useful Commands:"
echo "  • Create test user: cd KinduraAPIs-0.0.1 && ../.venv/bin/python manage.py shell"
echo "  • Create admin user: cd KinduraAPIs-0.0.1 && ../.venv/bin/python manage.py createsuperuser"
echo "  • Reset database: psql -d postgres -c 'DROP DATABASE kindura_db; CREATE DATABASE kindura_db;'"
echo ""
echo "💡 To switch to production:"
echo "  Change 'isLocalEnvironment = false' in lib/res/app_url/app_url.dart"