import threading
import time
import json
import requests
from django.db import transaction
from .models import UserJSON
from llm_model.gpt_model import GPTModel
from utils.llm_prompt import summarize_patient_report_prompt


def process_json_file_async(json_upload_id):
    """
    Background task to process JSON file asynchronously
    """
    try:
        gpt = GPTModel()
        with transaction.atomic():
            json_upload = UserJSON.objects.select_for_update().get(id=json_upload_id)
            json_upload.status = 'processing'
            json_upload.save()
        
        json_data = json_upload.data
        messages = [
                {"role": "system", "content": summarize_patient_report_prompt},
                {"role": "user", "content": str(json_data)}
            ]
        gpt = GPTModel()
        gpt_response = gpt.chat(messages)
        print(f"GPT response: {gpt_response}")
        try:
            gpt_json = json.loads(gpt_response)
        except Exception as e:
            print(f"GPT did not return valid JSON: {e}")

        print(f"GPT JSON: {gpt_json}")
        
        # Save course details to database if present
        if 'course_details' in gpt_json:
            try:
                save_course_details_to_database(gpt_json['course_details'], json_upload.user)
                print("Course details saved to database successfully")
            except Exception as e:
                print(f"Error saving course details to database: {e}")
        
        # Update the record with processing results
        with transaction.atomic():
            json_upload = UserJSON.objects.select_for_update().get(id=json_upload_id)
            json_upload.status = 'completed'
            json_upload.summarize_patient_report = gpt_json['conservation_summary']
            json_upload.save()
            
    except UserJSON.DoesNotExist:
        print(f"JSON upload with id {json_upload_id} not found")
    except Exception as e:
        # Handle any errors during processing
        try:
            with transaction.atomic():
                json_upload = UserJSON.objects.select_for_update().get(id=json_upload_id)
                json_upload.status = 'failed'
                json_upload.error_message = str(e)
                json_upload.save()
        except Exception:
            print(f"Failed to update error status for JSON upload {json_upload_id}")
        
        print(f"Error processing JSON upload {json_upload_id}: {str(e)}")


def start_background_processing(json_upload_id):
    """
    Start background processing in a separate thread
    """
    thread = threading.Thread(
        target=process_json_file_async,
        args=(json_upload_id,),
        daemon=True
    )
    thread.start()
    return thread


def save_course_details_to_database(course_details, user):
    """
    Save course details to the database using Django models directly
    """
    try:
        from schedules.models import CourseDayTracking
        from courses.models import Course
        from medicines.models import Medicine
        from datetime import datetime
        
        # Get course and medicine objects
        course_id = course_details.get("course")
        medicine_id = course_details.get("medicine")
        
        if not course_id or not medicine_id:
            print("Course ID or Medicine ID not provided in course_details")
            return False
        
        try:
            course = Course.objects.get(id=course_id, user=user)
            medicine = Medicine.objects.get(id=medicine_id, user=user)
        except (Course.DoesNotExist, Medicine.DoesNotExist) as e:
            print(f"Course or Medicine not found: {e}")
            return False
        
        # Parse date and time
        date_str = course_details.get("date")
        time_str = course_details.get("time")
        
        if not date_str or not time_str:
            print("Date or time not provided in course_details")
            return False
        
        try:
            date = datetime.strptime(date_str, "%Y-%m-%d").date()
            time = datetime.strptime(time_str, "%H:%M:%S").time()
        except ValueError as e:
            print(f"Invalid date or time format: {e}")
            return False
        
        # Create or update tracking entry
        tracking_entry, created = CourseDayTracking.objects.get_or_create(
            course=course,
            medicine=medicine,
            date=date,
            time=time,
            defaults={
                'taken': course_details.get("taken", False),
                'summary': course_details.get("summary", "")
            }
        )
        
        if not created:
            # Update existing entry
            tracking_entry.taken = course_details.get("taken", False)
            tracking_entry.summary = course_details.get("summary", "")
            tracking_entry.save()
        
        print(f"{'Created' if created else 'Updated'} tracking entry: {tracking_entry}")
        return True
        
    except Exception as e:
        print(f"Error in save_course_details_to_database: {e}")
        return False 