#!/usr/bin/env python3
"""
Test script to compare vitals data from:
1. Database (direct query)
2. REST API (what the agent uses)
3. WebSocket (real-time updates)

Run: python test_vitals_flow.py
"""
import os
import sys
import json
import asyncio
import aiohttp
import websockets
from asgiref.sync import sync_to_async

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
import django
django.setup()

from health_profile.models import WatchVitals
from users.models import User, UserToken

# Configuration
BASE_URL = "http://127.0.0.1:8000/api"
WS_URL = "ws://127.0.0.1:8000/ws/watch-vitals/"
TEST_EMAIL = "ralabaji@gmail.com"

@sync_to_async
def get_auth_token(email):
    """Get auth token for user"""
    user = User.objects.get(email=email)
    token = UserToken.objects.filter(user=user, is_active=True).first()
    return token.token if token else None

@sync_to_async
def test_database_direct():
    """Test 1: Query database directly"""
    print("\n" + "="*60)
    print("TEST 1: Direct Database Query")
    print("="*60)

    try:
        user = User.objects.get(email=TEST_EMAIL)
        latest = WatchVitals.objects.filter(user=user).order_by('-recorded_at').first()

        if latest:
            print(f"✅ Found vitals for {TEST_EMAIL}")
            print(f"   Heart Rate: {latest.heart_rate:.1f} bpm")
            print(f"   Blood Oxygen: {latest.blood_oxygen:.1f}%")
            print(f"   Recorded At: {latest.recorded_at}")
            print(f"   Sleep Hours: {latest.total_sleep_hours or 0}")
            print(f"   Awakenings: {latest.awakenings_count}")
            return {
                'heart_rate': latest.heart_rate,
                'blood_oxygen': latest.blood_oxygen,
                'recorded_at': str(latest.recorded_at)
            }
        else:
            print(f"❌ No vitals found for {TEST_EMAIL}")
            return None
    except User.DoesNotExist:
        print(f"❌ User {TEST_EMAIL} not found")
        return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

async def test_rest_api():
    """Test 2: REST API (what the agent uses)"""
    print("\n" + "="*60)
    print("TEST 2: REST API (Agent's Method)")
    print("="*60)

    token = await get_auth_token(TEST_EMAIL)
    if not token:
        print(f"❌ No auth token for {TEST_EMAIL}")
        return None

    print(f"🔑 Using token: {token[:20]}...")

    headers = {
        'Authorization': f'Token {token}',
        'Content-Type': 'application/json'
    }

    try:
        async with aiohttp.ClientSession() as session:
            url = f"{BASE_URL}/watch-vitals/"
            print(f"📡 Fetching from: {url}")

            async with session.get(url, headers=headers) as response:
                print(f"📥 Response status: {response.status}")

                if response.status == 200:
                    data = await response.json()
                    print(f"📥 Raw response: {json.dumps(data, indent=2)}")

                    if data.get('status') and data.get('result'):
                        result = data['result']
                        print(f"\n✅ API Response:")
                        print(f"   Heart Rate: {result.get('heart_rate')} bpm")
                        print(f"   Blood Oxygen: {result.get('blood_oxygen')}%")
                        print(f"   Sleep Hours: {result.get('sleep_hours')}")
                        print(f"   Awakenings: {result.get('awakenings')}")
                        print(f"   Is Demo: {result.get('is_demo')}")
                        print(f"   Last Updated: {result.get('last_updated')}")
                        return result
                    else:
                        print(f"❌ Invalid response format")
                        return None
                else:
                    text = await response.text()
                    print(f"❌ API Error: {text}")
                    return None
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return None

async def test_websocket():
    """Test 3: WebSocket connection"""
    print("\n" + "="*60)
    print("TEST 3: WebSocket Connection")
    print("="*60)

    try:
        print(f"🔌 Connecting to: {WS_URL}")
        async with websockets.connect(WS_URL) as ws:
            print("✅ WebSocket connected!")
            print("⏳ Waiting for vitals update (5 seconds)...")

            try:
                message = await asyncio.wait_for(ws.recv(), timeout=5.0)
                data = json.loads(message)
                print(f"📥 Received: {json.dumps(data, indent=2)}")
                return data
            except asyncio.TimeoutError:
                print("⏰ No message received within 5 seconds")
                print("   (This is normal if no new vitals are being sent)")
                return None
    except Exception as e:
        print(f"❌ WebSocket Error: {e}")
        return None

def compare_results(db_data, api_data, ws_data):
    """Compare results from all sources"""
    print("\n" + "="*60)
    print("COMPARISON SUMMARY")
    print("="*60)

    print("\n┌─────────────┬──────────────┬──────────────┬──────────────┐")
    print("│ Source      │ Heart Rate   │ Blood Oxygen │ Status       │")
    print("├─────────────┼──────────────┼──────────────┼──────────────┤")

    if db_data:
        print(f"│ Database    │ {db_data['heart_rate']:>10.1f}  │ {db_data['blood_oxygen']:>10.1f}% │ ✅ OK        │")
    else:
        print("│ Database    │     N/A      │     N/A      │ ❌ FAILED    │")

    if api_data:
        is_demo = "⚠️ DEMO" if api_data.get('is_demo') else "✅ OK"
        hr = api_data.get('heart_rate', 0)
        spo2 = api_data.get('blood_oxygen', 0)
        print(f"│ REST API    │ {hr:>10.1f}  │ {spo2:>10.1f}% │ {is_demo:<12} │")
    else:
        print("│ REST API    │     N/A      │     N/A      │ ❌ FAILED    │")

    if ws_data:
        print(f"│ WebSocket   │ (received)   │ (received)   │ ✅ OK        │")
    else:
        print("│ WebSocket   │     N/A      │     N/A      │ ⏰ No data   │")

    print("└─────────────┴──────────────┴──────────────┴──────────────┘")

    # Check for issues
    print("\n🔍 DIAGNOSTICS:")

    if not db_data:
        print("   ❌ No data in database for this user")
        print("      → Need to send vitals from Watch or use dev endpoint")

    if api_data and api_data.get('is_demo'):
        print("   ⚠️  API returning demo data instead of real data")
        print("      → Check if user has vitals in database")
        print("      → Check authentication token")

    if db_data and api_data and not api_data.get('is_demo'):
        db_hr = db_data['heart_rate']
        api_hr = api_data.get('heart_rate', 0)
        if abs(db_hr - api_hr) > 0.1:
            print(f"   ⚠️  HR mismatch: DB={db_hr:.1f}, API={api_hr:.1f}")
        else:
            print("   ✅ Database and API data match!")

    print("\n" + "="*60)

async def main():
    print("\n🔬 KINDURA VITALS FLOW TEST")
    print("Testing vitals data flow for:", TEST_EMAIL)

    # Run tests
    db_data = await test_database_direct()
    api_data = await test_rest_api()
    ws_data = await test_websocket()

    # Compare
    compare_results(db_data, api_data, ws_data)

    print("\n✨ Test complete!\n")

if __name__ == "__main__":
    asyncio.run(main())
