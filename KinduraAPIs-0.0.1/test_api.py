#!/usr/bin/env python3
"""
Medical App API Testing Script

This script provides comprehensive testing for all the medical app APIs.
Run this script to test all functionality of the medical app backend.

Usage:
    python test_api.py

Make sure the Django server is running on http://localhost:8000 before running this script.
"""

import requests
import json
from datetime import datetime, date
import time

# Base URL for the API
BASE_URL = "http://localhost:8000/api"

# Global variables to store data between tests
auth_token = None
user_id = None
course_id = None
medicine_id = None
schedule_id = None
tracking_id = None

def print_response(response, title="Response"):
    """Helper function to print API responses in a formatted way"""
    print(f"\n{'='*50}")
    print(f"{title}")
    print(f"{'='*50}")
    print(f"Status Code: {response.status_code}")
    print(f"Response:")
    try:
        print(json.dumps(response.json(), indent=2))
    except:
        print(response.text)
    print(f"{'='*50}\n")

def get_headers(token=None):
    """Helper function to get headers with optional authentication"""
    headers = {
        'Content-Type': 'application/json'
    }
    if token:
        headers['Authorization'] = token
    return headers

def test_user_signup():
    """Test user signup functionality"""
    print("Testing User Signup...")
    
    signup_data = {
        "email": "testuser@example.com",
        "password": "testpass123",
        "confirm_password": "testpass123",
        "username": "testuser"
    }
    
    response = requests.post(
        f"{BASE_URL}/users/signup/",
        headers=get_headers(),
        json=signup_data
    )
    
    print_response(response, "User Signup")
    
    global auth_token, user_id
    if response.status_code == 201:
        result = response.json()['result']
        auth_token = result['token']
        user_id = result['user']['id']
        print(f"✅ Signup successful! Token: {auth_token[:20]}...")
        print(f"✅ User ID: {user_id}")
        return True
    else:
        print("❌ Signup failed!")
        return False

def test_user_login():
    """Test user login functionality"""
    print("Testing User Login...")
    
    login_data = {
        "email": "testuser@example.com",
        "password": "testpass123"
    }
    
    response = requests.post(
        f"{BASE_URL}/users/login/",
        headers=get_headers(),
        json=login_data
    )
    
    print_response(response, "User Login")
    
    global auth_token, user_id
    if response.status_code == 200:
        result = response.json()['result']
        auth_token = result['token']
        user_id = result['user']['id']
        print(f"✅ Login successful! Token: {auth_token[:20]}...")
        print(f"✅ User ID: {user_id}")
        return True
    else:
        print("❌ Login failed!")
        return False

def test_get_profile():
    """Test getting user profile"""
    print("Testing Get User Profile...")
    
    response = requests.get(
        f"{BASE_URL}/users/profile/",
        headers=get_headers(auth_token)
    )
    
    print_response(response, "Get User Profile")
    
    if response.status_code == 200:
        print("✅ Get profile successful!")
        return True
    else:
        print("❌ Get profile failed!")
        return False

def test_update_profile():
    """Test updating user profile"""
    print("Testing Update User Profile...")
    
    profile_data = {
        "first_name": "John",
        "last_name": "Doe",
        "phone_number": "+1234567890",
        "age": 30,
        "gender": "M",
        "address": "123 Main Street, City, State 12345",
        "terms_and_conditions": True
    }
    
    response = requests.put(
        f"{BASE_URL}/users/profile/",
        headers=get_headers(auth_token),
        json=profile_data
    )
    
    print_response(response, "Update User Profile")
    
    if response.status_code == 200:
        print("✅ Update profile successful!")
        return True
    else:
        print("❌ Update profile failed!")
        return False

def test_create_health_profile():
    """Test creating health profile"""
    print("Testing Create Health Profile...")
    
    health_profile_data = {
        "lifestyle_habits": {
            "smoking": False,
            "drink_alcohol": False,
            "caffeine_intake": 2
        },
        "physical_activity": {
            "exercise_frequency": "3-4",
            "exercise_type": "gym",
            "average_duration": 60
        },
        "dietary_habits": {
            "diet_type": "vegetarian",
            "dietary_restrictions": "lactose intolerant",
            "daily_water_intake": 2.5
        },
        "medical_history": {
            "taking_medications": True,
            "current_medications": "Vitamin D, Iron supplements",
            "has_allergies": False,
            "allergies": "",
            "chronic_conditions": "None"
        },
        "mental_health": {
            "experienced_anxiety_depression": False,
            "seeing_therapist": False
        }
    }
    
    response = requests.post(
        f"{BASE_URL}/health-profile/profile/",
        headers=get_headers(auth_token),
        json=health_profile_data
    )
    
    print_response(response, "Create Health Profile")
    
    if response.status_code == 201:
        print("✅ Create health profile successful!")
        return True
    else:
        print("❌ Create health profile failed!")
        return False

def test_create_course():
    """Test creating a course"""
    print("Testing Create Course...")
    
    course_data = {
        "name": "Diabetes Management Course",
        "start_date": "2024-01-15",
        "duration": 30,
        "doctor_instructions": "Take medicines as prescribed, monitor blood sugar daily, exercise regularly"
    }
    
    response = requests.post(
        f"{BASE_URL}/courses/",
        headers=get_headers(auth_token),
        json=course_data
    )
    
    print_response(response, "Create Course")
    
    global course_id
    if response.status_code == 201:
        result = response.json()['result']
        course_id = result['id']
        print(f"✅ Create course successful! Course ID: {course_id}")
        return True
    else:
        print("❌ Create course failed!")
        return False

def test_create_medicine():
    """Test creating a medicine"""
    print("Testing Create Medicine...")
    
    medicine_data = {
        "name": "Metformin",
        "description": "Oral diabetes medicine that helps control blood sugar levels"
    }
    
    response = requests.post(
        f"{BASE_URL}/medicines/",
        headers=get_headers(auth_token),
        json=medicine_data
    )
    
    print_response(response, "Create Medicine")
    
    global medicine_id
    if response.status_code == 201:
        result = response.json()['result']
        medicine_id = result['id']
        print(f"✅ Create medicine successful! Medicine ID: {medicine_id}")
        return True
    else:
        print("❌ Create medicine failed!")
        return False

def test_create_schedule():
    """Test creating a schedule"""
    if not course_id or not medicine_id:
        print("⚠️  Course ID or Medicine ID not available. Skipping schedule test.")
        return False
    
    print("Testing Create Schedule...")
    
    schedule_data = {
        "course": course_id,
        "medicine": medicine_id,
        "time": "08:00:00",
        "dosage": "1 tablet"
    }
    
    response = requests.post(
        f"{BASE_URL}/schedules/",
        headers=get_headers(auth_token),
        json=schedule_data
    )
    
    print_response(response, "Create Schedule")
    
    global schedule_id
    if response.status_code == 201:
        result = response.json()['result']
        schedule_id = result['id']
        print(f"✅ Create schedule successful! Schedule ID: {schedule_id}")
        return True
    else:
        print("❌ Create schedule failed!")
        return False

def test_create_tracking():
    """Test creating a tracking entry"""
    if not course_id or not medicine_id:
        print("⚠️  Course ID or Medicine ID not available. Skipping tracking test.")
        return False
    
    print("Testing Create Tracking Entry...")
    
    tracking_data = {
        "course": course_id,
        "medicine": medicine_id,
        "date": date.today().isoformat(),
        "time": "08:00:00",
        "taken": True,
        "summary": "Felt good after taking medicine. Blood sugar levels normal."
    }
    
    response = requests.post(
        f"{BASE_URL}/tracking/",
        headers=get_headers(auth_token),
        json=tracking_data
    )
    
    print_response(response, "Create Tracking Entry")
    
    global tracking_id
    if response.status_code == 201:
        result = response.json()['result']
        tracking_id = result['id']
        print(f"✅ Create tracking entry successful! Tracking ID: {tracking_id}")
        return True
    else:
        print("❌ Create tracking entry failed!")
        return False

def test_list_endpoints():
    """Test listing all endpoints"""
    print("Testing List Endpoints...")
    
    endpoints = [
        ("courses", "Courses"),
        ("medicines", "Medicines"),
        ("schedules", "Schedules"),
        ("tracking", "Tracking Entries")
    ]
    
    for endpoint, name in endpoints:
        print(f"\nTesting List {name}...")
        response = requests.get(
            f"{BASE_URL}/{endpoint}/",
            headers=get_headers(auth_token)
        )
        
        if response.status_code == 200:
            print(f"✅ List {name} successful!")
        else:
            print(f"❌ List {name} failed!")

def test_error_handling():
    """Test error handling scenarios"""
    print("Testing Error Handling...")
    
    # Test invalid login
    print("\nTesting Invalid Login...")
    invalid_login_data = {
        "email": "testuser@example.com",
        "password": "wrongpassword"
    }
    
    response = requests.post(
        f"{BASE_URL}/users/login/",
        headers=get_headers(),
        json=invalid_login_data
    )
    
    if response.status_code == 400:
        print("✅ Invalid login correctly rejected!")
    else:
        print("❌ Invalid login should have been rejected!")
    
    # Test unauthorized access
    print("\nTesting Unauthorized Access...")
    response = requests.get(
        f"{BASE_URL}/courses/",
        headers=get_headers()  # No token
    )
    
    if response.status_code == 401:
        print("✅ Unauthorized access correctly rejected!")
    else:
        print("❌ Unauthorized access should have been rejected!")

def test_logout():
    """Test user logout"""
    global auth_token
    print("Testing User Logout...")
    
    response = requests.post(
        f"{BASE_URL}/users/logout/",
        headers=get_headers(auth_token)
    )
    
    print_response(response, "User Logout")
    
    if response.status_code == 200:
        print("✅ Logout successful!")
        auth_token = None
        return True
    else:
        print("❌ Logout failed!")
        return False

def test_upload_json():
    """Test uploading a JSON file for the user"""
    print("Testing Upload JSON File...")
    json_path = "testing_purpose/test_upload.json"
    try:
        with open(json_path, 'rb') as f:
            files = {'file': f}
            headers = {}
            if auth_token:
                headers['Authorization'] = auth_token if auth_token.startswith('Token') else f'Token {auth_token}'
            response = requests.post(
                f"{BASE_URL}/users/upload_json/",
                headers=headers,
                files=files
            )
            print_response(response, "Upload JSON File")
            if response.status_code == 201:
                print("✅ Upload JSON successful!")
                return True
            else:
                print("❌ Upload JSON failed!")
                return False
    except FileNotFoundError:
        print(f"❌ Test JSON file not found at {json_path}")
        return False

def main():
    """Main function to run all tests"""
    print("🚀 Starting Medical App API Tests")
    print("="*60)
    
    # Test results tracking
    test_results = []
    
    # User Management Tests
    print("\n📋 USER MANAGEMENT TESTS")
    print("-" * 30)
    test_results.append(("User Signup", test_user_signup()))
    test_results.append(("User Login", test_user_login()))
    test_results.append(("Get Profile", test_get_profile()))
    test_results.append(("Update Profile", test_update_profile()))
    
    # Health Profile Tests
    print("\n📋 HEALTH PROFILE TESTS")
    print("-" * 30)
    test_results.append(("Create Health Profile", test_create_health_profile()))
    
    # Course Management Tests
    print("\n📋 COURSE MANAGEMENT TESTS")
    print("-" * 30)
    test_results.append(("Create Course", test_create_course()))
    
    # Medicine Management Tests
    print("\n📋 MEDICINE MANAGEMENT TESTS")
    print("-" * 30)
    test_results.append(("Create Medicine", test_create_medicine()))
    
    # Schedule Management Tests
    print("\n📋 SCHEDULE MANAGEMENT TESTS")
    print("-" * 30)
    test_results.append(("Create Schedule", test_create_schedule()))
    
    # Tracking Tests
    print("\n📋 TRACKING TESTS")
    print("-" * 30)
    test_results.append(("Create Tracking", test_create_tracking()))
    
    # List Tests
    print("\n📋 LIST ENDPOINT TESTS")
    print("-" * 30)
    test_list_endpoints()
    
    # Error Handling Tests
    print("\n📋 ERROR HANDLING TESTS")
    print("-" * 30)
    test_error_handling()
    
    # Logout Test
    print("\n📋 LOGOUT TEST")
    print("-" * 30)
    test_results.append(("User Logout", test_logout()))

    # Upload JSON Test
    print("\n📋 UPLOAD JSON TEST")
    print("-" * 30)
    test_results.append(("Upload JSON", test_upload_json()))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for _, result in test_results if result)
    total = len(test_results)
    
    for test_name, result in test_results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    print(f"\nOverall Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The medical app backend is working correctly.")
    else:
        print("⚠️  Some tests failed. Please check the output above for details.")
    
    # Display created data summary
    print(f"\nCreated Data Summary:")
    print(f"User ID: {user_id}")
    print(f"Course ID: {course_id}")
    print(f"Medicine ID: {medicine_id}")
    print(f"Schedule ID: {schedule_id}")
    print(f"Tracking ID: {tracking_id}")
    
    print("\n" + "="*60)
    print("Testing completed!")
    print("="*60)

if __name__ == "__main__":
    main()

API_URL = 'http://localhost:8000/courses/with_medicines_and_schedules/'  # Update if needed
TOKEN = 'YOUR_AUTH_TOKEN'  # Replace with your actual token
PDF_PATH = 'testing_purpose/patient_summary_pdf_format.pdf'  # Update path if needed

headers = {
    'Authorization': f'Token {TOKEN}',
}

with open(PDF_PATH, 'rb') as pdf_file:
    files = {'pdf': pdf_file}
    response = requests.post(API_URL, headers=headers, files=files)
    print('Status code:', response.status_code)
    try:
        print('Response:', response.json())
    except Exception:
        print('Raw response:', response.text) 