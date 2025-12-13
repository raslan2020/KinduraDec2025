# Comprehensive Course Creation API Documentation

## Overview

This document describes the new comprehensive course creation API that allows you to create a course with its medicines and schedules in a single request. This eliminates the need for multiple API calls and ensures data consistency.

## New Endpoint

### Create Course with Medicines and Schedules

**Endpoint:** `POST /api/courses/with_medicines_and_schedules/`

**Description:** Creates a course along with its associated medicines and schedules in a single request.

**Authentication:** Required (Token-based)

**Request Format:**
```json
{
    "name": "Diabetes Management Course",
    "start_date": "2024-01-15",
    "duration": 30,
    "doctor_instructions": "Take medicines as prescribed and monitor blood sugar levels daily",
    "medicines_and_schedules": [
        {
            "medicine_name": "Metformin",
            "medicine_description": "Oral diabetes medicine that helps control blood sugar levels",
            "time": "08:00:00",
            "dosage": "500mg"
        },
        {
            "medicine_name": "Metformin",
            "medicine_description": "Oral diabetes medicine that helps control blood sugar levels",
            "time": "20:00:00",
            "dosage": "500mg"
        },
        {
            "medicine_name": "Insulin Glargine",
            "medicine_description": "Long-acting insulin injection",
            "time": "22:00:00",
            "dosage": "10 units"
        }
    ]
}
```

**Response Structure:**
```json
{
    "success": true,
    "message": "Course with medicines and schedules created successfully",
    "data": {
        "course": {
            "id": 1,
            "name": "Diabetes Management Course",
            "start_date": "2024-01-15",
            "duration": 30,
            "doctor_instructions": "Take medicines as prescribed and monitor blood sugar levels daily",
            "created_at": "2024-01-15T10:00:00Z",
            "is_active": true
        },
        "medicines": [
            {
                "id": 1,
                "name": "Metformin",
                "description": "Oral diabetes medicine that helps control blood sugar levels",
                "is_active": true
            },
            {
                "id": 2,
                "name": "Insulin Glargine",
                "description": "Long-acting insulin injection",
                "is_active": true
            }
        ],
        "schedules": [
            {
                "id": 1,
                "medicine_id": 1,
                "medicine_name": "Metformin",
                "time": "08:00:00",
                "dosage": "500mg",
                "is_active": true
            },
            {
                "id": 2,
                "medicine_id": 1,
                "medicine_name": "Metformin",
                "time": "20:00:00",
                "dosage": "500mg",
                "is_active": true
            },
            {
                "id": 3,
                "medicine_id": 2,
                "medicine_name": "Insulin Glargine",
                "time": "22:00:00",
                "dosage": "10 units",
                "is_active": true
            }
        ]
    }
}
```

## Field Descriptions

### Course Fields
- **name** (required): Name of the course
- **start_date** (required): Start date of the course (YYYY-MM-DD format)
- **duration** (required): Duration of the course in days (integer)
- **doctor_instructions** (required): Instructions from the doctor

### Medicine and Schedule Fields
- **medicine_name** (required): Name of the medicine
- **medicine_description** (optional): Description of the medicine
- **time** (required): Time to take the medicine (HH:MM:SS format)
- **dosage** (required): Dosage amount and unit

## How It Works

1. **Course Creation**: Creates the course with the provided details
2. **Medicine Management**: 
   - If a medicine with the same name doesn't exist, it creates a new one
   - If it exists, it uses the existing medicine
3. **Schedule Creation**: Creates schedules linking the course and medicines
4. **Response**: Returns all created data including course, medicines, and schedules

## Example Use Cases

### 1. Diabetes Management Course
```json
{
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
```

### 2. Hypertension Treatment Course
```json
{
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
```

### 3. Asthma Management Course
```json
{
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
```

## Frontend Implementation

### JavaScript Example
```javascript
// Create a course with medicines and schedules
async function createCourseWithMedicines(courseData) {
    try {
        const response = await fetch('/api/courses/with_medicines_and_schedules/', {
            method: 'POST',
            headers: {
                'Authorization': `Token ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(courseData)
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('Course created successfully:', result.data);
            
            // Access the created data
            const { course, medicines, schedules } = result.data;
            
            // Update UI with the new course
            displayCourse(course);
            displayMedicines(medicines);
            displaySchedules(schedules);
            
        } else {
            console.error('Error creating course:', result.message);
        }
    } catch (error) {
        console.error('Network error:', error);
    }
}

// Example usage
const courseData = {
    name: "Diabetes Management Course",
    start_date: "2024-01-15",
    duration: 30,
    doctor_instructions: "Take medicines as prescribed...",
    medicines_and_schedules: [
        {
            medicine_name: "Metformin",
            medicine_description: "Oral diabetes medicine...",
            time: "08:00:00",
            dosage: "500mg"
        }
    ]
};

createCourseWithMedicines(courseData);
```

### React Example
```jsx
import React, { useState } from 'react';

function CourseCreationForm() {
    const [courseData, setCourseData] = useState({
        name: '',
        start_date: '',
        duration: '',
        doctor_instructions: '',
        medicines_and_schedules: []
    });
    
    const [newMedicine, setNewMedicine] = useState({
        medicine_name: '',
        medicine_description: '',
        time: '',
        dosage: ''
    });
    
    const addMedicine = () => {
        setCourseData(prev => ({
            ...prev,
            medicines_and_schedules: [...prev.medicines_and_schedules, newMedicine]
        }));
        setNewMedicine({
            medicine_name: '',
            medicine_description: '',
            time: '',
            dosage: ''
        });
    };
    
    const createCourse = async () => {
        try {
            const response = await fetch('/api/courses/with_medicines_and_schedules/', {
                method: 'POST',
                headers: {
                    'Authorization': `Token ${token}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(courseData)
            });
            
            const result = await response.json();
            
            if (result.success) {
                alert('Course created successfully!');
                // Reset form or redirect
            } else {
                alert('Error: ' + result.message);
            }
        } catch (error) {
            alert('Network error: ' + error.message);
        }
    };
    
    return (
        <div>
            <h2>Create New Course</h2>
            
            {/* Course Details */}
            <div>
                <input
                    type="text"
                    placeholder="Course Name"
                    value={courseData.name}
                    onChange={(e) => setCourseData(prev => ({...prev, name: e.target.value}))}
                />
                <input
                    type="date"
                    value={courseData.start_date}
                    onChange={(e) => setCourseData(prev => ({...prev, start_date: e.target.value}))}
                />
                <input
                    type="number"
                    placeholder="Duration (days)"
                    value={courseData.duration}
                    onChange={(e) => setCourseData(prev => ({...prev, duration: e.target.value}))}
                />
                <textarea
                    placeholder="Doctor Instructions"
                    value={courseData.doctor_instructions}
                    onChange={(e) => setCourseData(prev => ({...prev, doctor_instructions: e.target.value}))}
                />
            </div>
            
            {/* Add Medicine Form */}
            <div>
                <h3>Add Medicine</h3>
                <input
                    type="text"
                    placeholder="Medicine Name"
                    value={newMedicine.medicine_name}
                    onChange={(e) => setNewMedicine(prev => ({...prev, medicine_name: e.target.value}))}
                />
                <input
                    type="text"
                    placeholder="Description"
                    value={newMedicine.medicine_description}
                    onChange={(e) => setNewMedicine(prev => ({...prev, medicine_description: e.target.value}))}
                />
                <input
                    type="time"
                    value={newMedicine.time}
                    onChange={(e) => setNewMedicine(prev => ({...prev, time: e.target.value}))}
                />
                <input
                    type="text"
                    placeholder="Dosage"
                    value={newMedicine.dosage}
                    onChange={(e) => setNewMedicine(prev => ({...prev, dosage: e.target.value}))}
                />
                <button onClick={addMedicine}>Add Medicine</button>
            </div>
            
            {/* Display Added Medicines */}
            <div>
                <h3>Added Medicines</h3>
                {courseData.medicines_and_schedules.map((medicine, index) => (
                    <div key={index}>
                        {medicine.medicine_name} - {medicine.time} - {medicine.dosage}
                    </div>
                ))}
            </div>
            
            <button onClick={createCourse}>Create Course</button>
        </div>
    );
}
```

## Error Handling

### Validation Errors
```json
{
    "success": false,
    "message": "Validation error",
    "data": {
        "name": ["This field is required."],
        "start_date": ["Start date cannot be in the past."],
        "medicines_and_schedules": [
            {
                "time": ["This field is required."],
                "dosage": ["This field is required."]
            }
        ]
    }
}
```

### Common Error Scenarios
- **400 Bad Request**: Validation errors in the request data
- **401 Unauthorized**: Invalid or missing authentication token
- **500 Internal Server Error**: Server-side errors during creation

## Benefits

1. **Single Request**: Create course, medicines, and schedules in one API call
2. **Data Consistency**: All related data is created atomically
3. **Reduced Complexity**: Frontend doesn't need to manage multiple API calls
4. **Automatic Medicine Management**: Handles existing vs new medicines automatically
5. **Comprehensive Response**: Returns all created data for immediate use

## Testing

Use the provided test script to verify the API:

```bash
python test_comprehensive_create_api.py
```

This script demonstrates:
- Creating different types of medical courses
- Adding multiple medicines and schedules
- Error handling and validation
- Response structure verification 