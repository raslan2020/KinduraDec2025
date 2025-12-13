# Medical App Backend

A Django REST Framework backend for a medical application that helps users manage their health profiles, courses, medicines, and medication schedules.

## Features

### 1. User Management
- **Signup API**: Register with email, password, and confirm password
- **Login API**: Authenticate with email and password
- **Profile API**: Get and update user profile (name, phone, age, gender, address, terms & conditions)
- **Simple Token Authentication**: Custom token-based authentication system

### 2. Health Profile Management
- **Lifestyle Habits**: Smoking, alcohol consumption, caffeine intake
- **Physical Activity**: Exercise frequency, type, and duration
- **Dietary Habits**: Diet type, restrictions, water intake
- **Medical History**: Current medications, allergies, chronic conditions
- **Mental Health**: Anxiety/depression history, therapy status

### 3. Course Management
- Create and manage medical courses
- Track course start date, duration, and doctor instructions
- Soft delete functionality

### 4. Medicine Management
- Add and manage medicines with descriptions
- Soft delete functionality

### 5. Schedule Management
- Create medicine schedules for courses
- Set specific times and dosages
- Soft delete functionality

### 6. Day Tracking
- Track daily medicine intake
- Mark medicines as taken/not taken
- Add daily summaries

## Project Structure

```
medical_app/
├── medical_app/          # Main Django project
│   ├── settings.py       # Django settings
│   ├── urls.py          # Main URL configuration
│   └── wsgi.py          # WSGI configuration
├── users/               # User management app
├── health_profile/      # Health profile management app
├── courses/            # Course management app
├── medicines/          # Medicine management app
├── schedules/          # Schedule and tracking app
├── utils/              # Utility functions
│   ├── response_utils.py    # Standardized API responses
│   └── authentication.py    # Custom authentication
├── manage.py           # Django management script
├── requirements.txt    # Python dependencies
└── README.md          # This file
```

## Setup Instructions

### 1. Clone the repository
```bash
git clone <repository-url>
cd medical_app
```

### 2. Create virtual environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install dependencies
```bash
pip install -r requirements.txt
```

### 4. Run migrations
```bash
python manage.py makemigrations
python manage.py migrate
```

### 5. Create superuser (optional)
```bash
python manage.py createsuperuser
```

### 6. Run the development server
```bash
python manage.py runserver
```

The API will be available at `http://localhost:8000/api/`

## API Documentation

### Authentication
All APIs (except signup and login) require authentication using the token in the Authorization header:
```
Authorization: <token>
```

### Response Format
All APIs return responses in the following format:

**Success Response:**
```json
{
    "status": true,
    "result": {
        // response data
    }
}
```

**Error Response:**
```json
{
    "status": false,
    "result": {
        "error": "Error message"
    }
}
```

### API Endpoints

#### User Management

**1. Signup**
- **URL**: `POST /api/users/signup/`
- **Body**:
```json
{
    "email": "user@example.com",
    "password": "password123",
    "confirm_password": "password123",
    "username": "username"
}
```

**2. Login**
- **URL**: `POST /api/users/login/`
- **Body**:
```json
{
    "email": "user@example.com",
    "password": "password123"
}
```

**3. Profile (GET)**
- **URL**: `GET /api/users/profile/`
- **Headers**: `Authorization: <token>`

**4. Profile (PUT)**
- **URL**: `PUT /api/users/profile/`
- **Headers**: `Authorization: <token>`
- **Body**:
```json
{
    "name": "John Doe",
    "phone_number": "+1234567890",
    "age": 30,
    "gender": "M",
    "address": "123 Main St",
    "terms_and_conditions": true
}
```

**5. Logout**
- **URL**: `POST /api/users/logout/`
- **Headers**: `Authorization: <token>`

#### Health Profile

**1. Get Health Profile**
- **URL**: `GET /api/health-profile/profile/`
- **Headers**: `Authorization: <token>`

**2. Create Health Profile**
- **URL**: `POST /api/health-profile/profile/`
- **Headers**: `Authorization: <token>`
- **Body**:
```json
{
    "lifestyle_habits": {
        "smoking": false,
        "drink_alcohol": false,
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
        "taking_medications": true,
        "current_medications": "Vitamin D, Iron",
        "has_allergies": false,
        "allergies": "",
        "chronic_conditions": "None"
    },
    "mental_health": {
        "experienced_anxiety_depression": false,
        "seeing_therapist": false
    }
}
```

**3. Update Health Profile**
- **URL**: `PUT /api/health-profile/profile/`
- **Headers**: `Authorization: <token>`
- **Body**: Same as create (partial updates supported)

#### Courses

**1. List Courses**
- **URL**: `GET /api/courses/`
- **Headers**: `Authorization: <token>`

**2. Create Course**
- **URL**: `POST /api/courses/`
- **Headers**: `Authorization: <token>`
- **Body**:
```json
{
    "name": "Diabetes Management",
    "start_date": "2024-01-15",
    "duration": 30,
    "doctor_instructions": "Take medicines as prescribed"
}
```

**3. Get Course**
- **URL**: `GET /api/courses/{id}/`
- **Headers**: `Authorization: <token>`

**4. Update Course**
- **URL**: `PUT /api/courses/{id}/`
- **Headers**: `Authorization: <token>`

**5. Delete Course**
- **URL**: `DELETE /api/courses/{id}/`
- **Headers**: `Authorization: <token>`

#### Medicines

**1. List Medicines**
- **URL**: `GET /api/medicines/`
- **Headers**: `Authorization: <token>`

**2. Create Medicine**
- **URL**: `POST /api/medicines/`
- **Headers**: `Authorization: <token>`
- **Body**:
```json
{
    "name": "Metformin",
    "description": "Diabetes medication"
}
```

**3. Get Medicine**
- **URL**: `GET /api/medicines/{id}/`
- **Headers**: `Authorization: <token>`

**4. Update Medicine**
- **URL**: `PUT /api/medicines/{id}/`
- **Headers**: `Authorization: <token>`

**5. Delete Medicine**
- **URL**: `DELETE /api/medicines/{id}/`
- **Headers**: `Authorization: <token>`

#### Schedules

**1. List Schedules**
- **URL**: `GET /api/schedules/`
- **Headers**: `Authorization: <token>`

**2. Create Schedule**
- **URL**: `POST /api/schedules/`
- **Headers**: `Authorization: <token>`
- **Body**:
```json
{
    "course": 1,
    "medicine": 1,
    "time": "08:00:00",
    "dosage": "1 tablet"
}
```

**3. Get Schedule**
- **URL**: `GET /api/schedules/{id}/`
- **Headers**: `Authorization: <token>`

**4. Update Schedule**
- **URL**: `PUT /api/schedules/{id}/`
- **Headers**: `Authorization: <token>`

**5. Delete Schedule**
- **URL**: `DELETE /api/schedules/{id}/`
- **Headers**: `Authorization: <token>`

#### Tracking

**1. List Tracking Entries**
- **URL**: `GET /api/tracking/`
- **Headers**: `Authorization: <token>`

**2. Create Tracking Entry**
- **URL**: `POST /api/tracking/`
- **Headers**: `Authorization: <token>`
- **Body**:
```json
{
    "course": 1,
    "medicine": 1,
    "date": "2024-01-15",
    "time": "08:00:00",
    "taken": true,
    "summary": "Felt good after taking medicine"
}
```

**3. Get Tracking Entry**
- **URL**: `GET /api/tracking/{id}/`
- **Headers**: `Authorization: <token>`

**4. Update Tracking Entry**
- **URL**: `PUT /api/tracking/{id}/`
- **Headers**: `Authorization: <token>`

**5. Delete Tracking Entry**
- **URL**: `DELETE /api/tracking/{id}/`
- **Headers**: `Authorization: <token>`

## Admin Interface

Access the Django admin interface at `http://localhost:8000/admin/` to manage all data through a web interface.

## Development

### Running Tests
```bash
python manage.py test
```

### Making Migrations
```bash
python manage.py makemigrations
python manage.py migrate
```

### Creating a Superuser
```bash
python manage.py createsuperuser
```

## Security Notes

- Change the `SECRET_KEY` in `settings.py` for production
- Set `DEBUG = False` for production
- Configure proper CORS settings for production
- Use environment variables for sensitive settings
- Consider using HTTPS in production

## License

This project is licensed under the MIT License. 