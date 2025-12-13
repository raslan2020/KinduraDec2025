#!/usr/bin/env python3
"""
Test script for the comprehensive CREATE API
This script demonstrates creating a course with medicines and schedules in one request
"""

import requests
import json
from datetime import datetime, time

# API base URL
BASE_URL = "http://localhost:8000/api"

def print_response(response, title):
    """Print formatted API response"""
    print(f"\n{'='*60}")
    print(f"{title}")
    print(f"{'='*60}")
    print(f"Status Code: {response.status_code}")
    print(f"Response:")
    print(json.dumps(response.json(), indent=2, default=str))

def test_comprehensive_create_api():
    """Test the comprehensive course creation API"""
    
    # First, let's login to get a token
    print("1. Logging in to get authentication token...")
    login_data = {
        "email": "testuser@example.com",
        "password": "testpass123"
    }
    
    login_response = requests.post(f"{BASE_URL}/users/login/", json=login_data)
    if login_response.status_code != 200:
        print("Login failed. Creating a new user...")
        signup_data = {
            "username": "testuser",
            "email": "testuser@example.com",
            "password": "testpass123",
            "first_name": "Test",
            "last_name": "User"
        }
        signup_response = requests.post(f"{BASE_URL}/users/signup/", json=signup_data)
        if signup_response.status_code == 201:
            token = signup_response.json()['data']['token']
        else:
            print("Failed to create user")
            return
    else:
        token = login_response.json()['data']['token']
    
    headers = {
        "Authorization": f"Token {token}",
        "Content-Type": "application/json"
    }
    
    print(f"Token obtained: {token[:20]}...")
    
    # 2. Test the comprehensive course creation API
    print("\n2. Testing comprehensive course creation API...")
    
    # Example 1: Diabetes Management Course
    diabetes_course_data = {
        "name": "Diabetes Management Course",
        "start_date": "2024-01-15",
        "duration": 30,
        "doctor_instructions": "Take medicines as prescribed and monitor blood sugar levels daily. Check blood sugar before meals and at bedtime.",
        "medicines_and_schedules": [
            {
                "medicine_name": "Metformin",
                "medicine_description": "Oral diabetes medicine that helps control blood sugar levels by improving insulin sensitivity",
                "time": "08:00:00",
                "dosage": "500mg"
            },
            {
                "medicine_name": "Metformin",
                "medicine_description": "Oral diabetes medicine that helps control blood sugar levels by improving insulin sensitivity",
                "time": "20:00:00",
                "dosage": "500mg"
            },
            {
                "medicine_name": "Insulin Glargine",
                "medicine_description": "Long-acting insulin injection that provides basal insulin coverage",
                "time": "22:00:00",
                "dosage": "10 units"
            }
        ]
    }
    
    print("\nCreating Diabetes Management Course...")
    diabetes_response = requests.post(
        f"{BASE_URL}/courses/with_medicines_and_schedules/", 
        json=diabetes_course_data, 
        headers=headers
    )
    print_response(diabetes_response, "DIABETES COURSE CREATION")
    
    # Example 2: Hypertension Treatment Course
    hypertension_course_data = {
        "name": "Hypertension Treatment Course",
        "start_date": "2024-01-20",
        "duration": 60,
        "doctor_instructions": "Take blood pressure medication daily. Monitor blood pressure weekly and report any side effects.",
        "medicines_and_schedules": [
            {
                "medicine_name": "Lisinopril",
                "medicine_description": "ACE inhibitor that helps relax blood vessels and lower blood pressure",
                "time": "07:00:00",
                "dosage": "10mg"
            },
            {
                "medicine_name": "Amlodipine",
                "medicine_description": "Calcium channel blocker that helps relax blood vessels",
                "time": "19:00:00",
                "dosage": "5mg"
            },
            {
                "medicine_name": "Hydrochlorothiazide",
                "medicine_description": "Diuretic that helps remove excess water and salt from the body",
                "time": "08:00:00",
                "dosage": "25mg"
            }
        ]
    }
    
    print("\nCreating Hypertension Treatment Course...")
    hypertension_response = requests.post(
        f"{BASE_URL}/courses/with_medicines_and_schedules/", 
        json=hypertension_course_data, 
        headers=headers
    )
    print_response(hypertension_response, "HYPERTENSION COURSE CREATION")
    
    # Example 3: Asthma Management Course
    asthma_course_data = {
        "name": "Asthma Management Course",
        "start_date": "2024-01-25",
        "duration": 90,
        "doctor_instructions": "Use inhalers as prescribed. Keep rescue inhaler with you at all times. Avoid triggers like dust and smoke.",
        "medicines_and_schedules": [
            {
                "medicine_name": "Albuterol Inhaler",
                "medicine_description": "Short-acting beta agonist for quick relief of asthma symptoms",
                "time": "08:00:00",
                "dosage": "2 puffs"
            },
            {
                "medicine_name": "Albuterol Inhaler",
                "medicine_description": "Short-acting beta agonist for quick relief of asthma symptoms",
                "time": "20:00:00",
                "dosage": "2 puffs"
            },
            {
                "medicine_name": "Fluticasone Inhaler",
                "medicine_description": "Inhaled corticosteroid for long-term asthma control",
                "time": "08:00:00",
                "dosage": "1 puff"
            },
            {
                "medicine_name": "Fluticasone Inhaler",
                "medicine_description": "Inhaled corticosteroid for long-term asthma control",
                "time": "20:00:00",
                "dosage": "1 puff"
            }
        ]
    }
    
    print("\nCreating Asthma Management Course...")
    asthma_response = requests.post(
        f"{BASE_URL}/courses/with_medicines_and_schedules/", 
        json=asthma_course_data, 
        headers=headers
    )
    print_response(asthma_response, "ASTHMA COURSE CREATION")
    
    # 3. Test regular course creation for comparison
    print("\n3. Testing regular course creation for comparison...")
    regular_course_data = {
        "name": "Regular Course (No Medicines)",
        "start_date": "2024-02-01",
        "duration": 15,
        "doctor_instructions": "This is a regular course without medicines and schedules"
    }
    
    regular_response = requests.post(f"{BASE_URL}/courses/", json=regular_course_data, headers=headers)
    print_response(regular_response, "REGULAR COURSE CREATION")
    
    # 4. List all courses to see what was created
    print("\n4. Listing all courses to see what was created...")
    courses_response = requests.get(f"{BASE_URL}/courses/", headers=headers)
    print_response(courses_response, "ALL COURSES LIST")

def main():
    """Main function"""
    print("Testing Comprehensive Course Creation API")
    print("This script demonstrates creating courses with medicines and schedules in a single request")
    
    try:
        test_comprehensive_create_api()
        print("\n" + "="*60)
        print("API Testing Completed Successfully!")
        print("="*60)
        
        print("\nKey Features Demonstrated:")
        print("1. Create course with multiple medicines and schedules in one request")
        print("2. Automatic medicine creation if they don't exist")
        print("3. Automatic schedule creation linking course and medicines")
        print("4. Comprehensive response with all created data")
        print("5. Data validation and error handling")
        
        print("\nAPI Endpoint:")
        print("POST /api/courses/with_medicines_and_schedules/")
        
        print("\nRequest Format:")
        print("""
{
    "name": "Course Name",
    "start_date": "YYYY-MM-DD",
    "duration": 30,
    "doctor_instructions": "Instructions from doctor",
    "medicines_and_schedules": [
        {
            "medicine_name": "Medicine Name",
            "medicine_description": "Medicine description",
            "time": "HH:MM:SS",
            "dosage": "Dosage amount"
        }
    ]
}
        """)
        
    except requests.exceptions.ConnectionError:
        print("Error: Could not connect to the server. Make sure the Django server is running on localhost:8000")
    except Exception as e:
        print(f"Error during testing: {e}")

if __name__ == "__main__":
    main() 