import datetime
import os
from dotenv import load_dotenv
import json
import utils.global_variables as global_variables
from utils.global_variables import BASE_URL
from livekit import agents
from livekit.agents import AgentSession, Agent, RoomInputOptions, RoomOutputOptions
from livekit.plugins import (
    deepgram,
    noise_cancellation,
    silero,
    openai,
)
from livekit import rtc
# Removed MultilingualModel import - causes SDK compatibility issues
# from livekit.plugins.turn_detector.multilingual import MultilingualModel
from livekit.agents.llm import function_tool, ToolContext
from utils.json_to_be import upload_json
from utils.medical_report_api import get_medical_report_service
from utils.medication_api import get_medication_service
from utils.watch_vitals_api import get_watch_vitals_service
from utils.contacts_api import ContactsAPI
from utils.observations_api import ObservationsAPI
from utils.biomarkers_api import BiomarkersAPI

def print_response(response, context):
    print(f"[{context}] Status: {response.status_code}, Response: {response.text}")

load_dotenv()


class Assistant(Agent):
    def __init__(self, instruction_agent_prompt: str) -> None:
        super().__init__(instructions=instruction_agent_prompt)


# Global variables to store services for function tools
_medication_service = None
_observations_service = None
_biomarkers_service = None
_base_url = None
_auth_token = None


@function_tool(description="Called when patient asks to mark medication as taken or update medication schedule. This action must be done by the user or caregiver in the app, not by the voice assistant.")
async def mark_medication_taken(medication_name: str, notes: str = "", taken_on_time: bool = False, delay_minutes: int = 0) -> str:
    """Decline marking medication - must be done in app by user or caregiver"""
    print(f"🚫 User requested to mark {medication_name} as taken - declining (must be done in app)")
    return f"I'm sorry, but I'm not able to mark your medications as taken or update your medication schedule. For accuracy and safety, this needs to be done by you or your caregiver directly in the Kindura app. You can go to the Medications tab and tap on the medication to mark it as taken. Would you like me to help you with something else?"


@function_tool(description="Called when patient says they missed or skipped their medication. This action must be recorded by the user or caregiver in the app, not by the voice assistant.")
async def mark_medication_missed(medication_name: str, reason: str = "") -> str:
    """Decline marking medication as missed - must be done in app by user or caregiver"""
    print(f"🚫 User reported missing {medication_name} - declining to record (must be done in app)")

    # Still provide helpful guidance about missed doses
    guidance = f"I understand you missed your {medication_name}. While I can't update your medication records directly, I can offer some general guidance. "
    guidance += "If it's close to your next scheduled dose, you may want to skip the missed dose. If there's plenty of time, you might still take it. "
    guidance += "For important medications, please check with your pharmacist or doctor. "
    guidance += "To record this missed dose, please use the Kindura app directly or ask your caregiver to update it for you."

    return guidance


def _find_next_scheduled_time(times: list, current_time) -> datetime:
    """Find the next scheduled time after current time"""
    from datetime import datetime
    today = current_time.date()

    for time_str in sorted(times):
        try:
            parts = time_str.split(':')
            hour = int(parts[0])
            minute = int(parts[1]) if len(parts) > 1 else 0
            sched_dt = datetime.combine(today, datetime.min.time().replace(hour=hour, minute=minute))

            if sched_dt > current_time:
                return sched_dt
        except:
            pass

    # If no time found today, return first time tomorrow
    if times:
        try:
            parts = sorted(times)[0].split(':')
            hour = int(parts[0])
            minute = int(parts[1]) if len(parts) > 1 else 0
            from datetime import timedelta
            tomorrow = today + timedelta(days=1)
            return datetime.combine(tomorrow, datetime.min.time().replace(hour=hour, minute=minute))
        except:
            pass

    return None


def _calculate_shifted_schedule(times: list, current_time, missed_by_minutes: int) -> str:
    """Calculate shifted schedule for fixed-time medications"""
    from datetime import datetime, timedelta

    today = current_time.date()
    remaining_times = []

    for time_str in sorted(times):
        try:
            parts = time_str.split(':')
            hour = int(parts[0])
            minute = int(parts[1]) if len(parts) > 1 else 0
            sched_dt = datetime.combine(today, datetime.min.time().replace(hour=hour, minute=minute))

            if sched_dt > current_time:
                # Shift by minimum of missed time or 2 hours
                shift_minutes = min(missed_by_minutes, 120)
                shifted_dt = sched_dt + timedelta(minutes=shift_minutes)
                original_str = sched_dt.strftime('%I:%M %p').lstrip('0')
                shifted_str = shifted_dt.strftime('%I:%M %p').lstrip('0')
                remaining_times.append(f"{original_str} shifted to {shifted_str}")
        except:
            pass

    if remaining_times:
        return f"Your remaining doses today are shifted: {', '.join(remaining_times)}. Your schedule will return to normal tomorrow."
    else:
        return "This was your last dose of the day. Your schedule will return to normal tomorrow."


@function_tool(description="Get the latest medication list from the database. Call this to refresh and get current medications.")
async def get_current_medications() -> str:
    """Fetch fresh medication list from database"""
    global _medication_service
    print(f"🔄 Refreshing medication list from database...")

    if not _medication_service:
        return "Unable to fetch medications - service not available."

    medications = await _medication_service.get_medications(active_only=True)

    if medications:
        formatted = _medication_service.format_medications_for_agent(medications)
        print(f"💊 Refreshed: {len(medications)} medications found")
        return formatted
    else:
        return "No active medications found in your profile."


@function_tool(description="Get today's medication adherence status showing taken, pending, and missed doses.")
async def get_medication_status() -> str:
    """Get today's medication adherence summary"""
    global _medication_service
    print(f"📊 Getting medication status...")

    if not _medication_service:
        return "Unable to fetch status - service not available."

    try:
        adherence = await _medication_service.get_adherence_summary(period='today')
        if adherence:
            taken = adherence.get('todayTaken', 0)
            pending = adherence.get('todayPending', 0)
            missed = adherence.get('todayMissed', 0)

            status = f"Today's medication status: {taken} taken, {pending} pending, {missed} missed."

            if pending > 0:
                status += f" You still have {pending} dose(s) to take today."
            if missed > 0:
                status += f" You missed {missed} dose(s) today."
            if taken > 0 and pending == 0 and missed == 0:
                status += " Great job! You've taken all your medications for today."

            return status
        else:
            return "No medication status available for today."
    except Exception as e:
        print(f"❌ Error getting medication status: {e}")
        return "Unable to retrieve medication status at this time."


@function_tool(description="Report a side effect from medication. Call this when the patient mentions experiencing side effects.")
async def report_side_effect(medication_name: str, symptom: str, severity: str = "mild") -> str:
    """Record a side effect report"""
    global _observations_service
    print(f"📋 Recording side effect for {medication_name}: {symptom} ({severity})")

    # Save observation to database
    if _observations_service:
        await _observations_service.save_side_effect(
            medication_name=medication_name,
            symptom=symptom,
            severity=severity
        )
        print(f"📝 Side effect saved to database: {medication_name} - {symptom} - Severity: {severity}")

    if severity == 'severe':
        return f"I've recorded this severe side effect. Please contact your doctor immediately about this {symptom} from {medication_name}."
    elif severity == 'moderate':
        return f"I've noted this side effect. You should mention this {symptom} to your doctor at your next appointment."
    else:
        return f"I've recorded this side effect. Keep monitoring it and let me know if it gets worse."


@function_tool(description="Save a sleep observation. Call this when the patient reports about their sleep (hours, quality). Quality can be: good, fair, or poor.")
async def save_sleep_report(hours: float = None, quality: str = "", notes: str = "") -> str:
    """Save a sleep observation to the database"""
    global _observations_service
    print(f"😴 Saving sleep observation: {hours}h, quality={quality}")

    if _observations_service:
        result = await _observations_service.save_sleep_observation(
            hours=hours,
            quality=quality if quality else None,
            notes=notes if notes else None
        )
        if result:
            print(f"✅ Sleep observation saved to database")
            response = "I've noted your sleep information."
            if hours is not None:
                if hours < 6:
                    response += f" Getting {hours} hours is less than ideal. Try to aim for 7-8 hours for better health."
                else:
                    response += f" {hours} hours is good rest."
            if quality == 'poor':
                response += " I'm sorry to hear your sleep quality wasn't great. Let me know if this continues."
            return response

    return "I've noted your sleep information."


@function_tool(description="Save a mood observation. Call this when the patient shares how they're feeling emotionally. Mood examples: good, okay, happy, sad, anxious, stressed, tired, energetic.")
async def save_mood_report(mood: str, notes: str = "") -> str:
    """Save a mood observation to the database"""
    global _observations_service
    print(f"😊 Saving mood observation: {mood}")

    if _observations_service:
        result = await _observations_service.save_mood_observation(
            mood=mood,
            notes=notes if notes else None
        )
        if result:
            print(f"✅ Mood observation saved to database")

    # Respond based on mood
    positive_moods = ['good', 'great', 'happy', 'energetic', 'positive', 'wonderful', 'excellent']
    negative_moods = ['sad', 'anxious', 'stressed', 'depressed', 'worried', 'tired', 'exhausted']

    if mood.lower() in positive_moods:
        return f"I'm glad to hear you're feeling {mood}! I've noted this for your health record."
    elif mood.lower() in negative_moods:
        return f"I'm sorry you're feeling {mood}. I've noted this and it will be included in your report for your doctor. Is there anything specific bothering you?"
    else:
        return f"I've noted that you're feeling {mood}. This helps track your overall well-being."


@function_tool(description="Save a symptom observation. Call this when the patient reports any physical symptoms like headache, nausea, dizziness, pain, fatigue, etc. Severity can be: mild, moderate, or severe.")
async def save_symptom_report(symptom: str, severity: str = "mild", notes: str = "") -> str:
    """Save a symptom observation to the database"""
    global _observations_service
    print(f"🤒 Saving symptom observation: {symptom} ({severity})")

    if _observations_service:
        result = await _observations_service.save_symptom_observation(
            symptom=symptom,
            severity=severity,
            notes=notes if notes else None
        )
        if result:
            print(f"✅ Symptom observation saved to database")

    if severity == 'severe':
        return f"I've recorded your {symptom}. Since this is severe, please consider contacting your doctor or caregiver if it doesn't improve soon."
    elif severity == 'moderate':
        return f"I've noted your {symptom}. Please monitor it and let me know if it gets worse."
    else:
        return f"I've noted your {symptom}. I'll keep track of this for your health report."


@function_tool(description="Save an energy level observation. Call this when the patient mentions their energy level. Level can be: high, normal, low, or very low.")
async def save_energy_report(level: str, notes: str = "") -> str:
    """Save an energy level observation to the database"""
    global _observations_service
    print(f"⚡ Saving energy observation: {level}")

    if _observations_service:
        result = await _observations_service.save_energy_observation(
            level=level,
            notes=notes if notes else None
        )
        if result:
            print(f"✅ Energy observation saved to database")

    if level.lower() in ['low', 'very low', 'tired', 'exhausted']:
        return f"I've noted that your energy is {level}. Make sure you're getting enough rest and staying hydrated. Let me know if this continues."
    else:
        return f"Great to hear your energy level is {level}! I've noted this for your health record."


@function_tool(description="Save a fall event. Call this if the patient reports a fall or near-fall incident. Severity can be: mild, moderate, or severe.")
async def save_fall_report(description: str, injury_reported: bool = False, severity: str = "moderate") -> str:
    """Save a fall event to the database"""
    global _observations_service
    print(f"⚠️ Saving fall observation: injury={injury_reported}, severity={severity}")

    if _observations_service:
        result = await _observations_service.save_fall_observation(
            description=description,
            severity=severity,
            injury_reported=injury_reported
        )
        if result:
            print(f"✅ Fall observation saved to database")

    if injury_reported:
        return "I've recorded this fall with injury. This is concerning - please have someone check on you and consider calling your doctor or emergency contact. Are you okay right now?"
    else:
        return "I've recorded this fall. I'm glad you're okay. Falls can be serious, so please be careful. I'll make sure your doctor is aware of this in your report."


@function_tool(description="Save a general health observation. Call this for any health-related information the patient shares that doesn't fit other categories.")
async def save_general_observation(title: str, description: str, severity: str = "normal") -> str:
    """Save a general observation to the database"""
    global _observations_service
    print(f"📝 Saving general observation: {title}")

    if _observations_service:
        result = await _observations_service.save_general_observation(
            title=title,
            description=description,
            severity=severity
        )
        if result:
            print(f"✅ General observation saved to database")

    return f"I've noted this information for your health record."


@function_tool(description="Get current vitals from Apple Watch. Call this to check the patient's latest health data.")
async def get_watch_vitals() -> str:
    """Fetch latest Watch vitals"""
    global _base_url, _auth_token
    print(f"⌚ Fetching latest Watch vitals...")

    if not _base_url or not _auth_token:
        return "Unable to fetch vitals - service not configured."

    watch_service = get_watch_vitals_service(_base_url, _auth_token)
    vitals = await watch_service.get_latest_vitals()

    if vitals and not vitals.get('is_demo'):
        return watch_service.format_vitals_for_agent(vitals)
    else:
        return "No Apple Watch data available at this time."


@function_tool(description="Get the patient's lab results and biomarkers. Call this when patient asks about their lab results, blood tests, cholesterol, glucose, or any biomarker. Optional category filter: heart_health, liver, kidney, diabetes, thyroid, blood_count, vitamins.")
async def get_lab_results(category: str = "") -> str:
    """Fetch lab results and biomarkers from database"""
    global _biomarkers_service
    print(f"🔬 Fetching lab results... (category: {category if category else 'all'})")
    print(f"🔬 Biomarkers service available: {_biomarkers_service is not None}")

    if not _biomarkers_service:
        print("❌ Biomarkers service not initialized!")
        return "Unable to fetch lab results - service not available."

    try:
        print(f"🔬 Calling get_all_biomarkers API...")
        result = await _biomarkers_service.get_all_biomarkers(
            category=category if category else None
        )
        print(f"🔬 API response type: {type(result)}")
        print(f"🔬 API response: {str(result)[:500] if result else 'None'}")

        if result:
            # The API returns a dict with 'result' containing the list of biomarkers
            # Or it might return a list directly
            if isinstance(result, list):
                biomarker_list = result
            elif isinstance(result, dict):
                # Check for 'result' key (API response structure)
                biomarker_list = result.get('result', result.get('biomarkers', []))
                if not isinstance(biomarker_list, list):
                    biomarker_list = [result] if result else []
            else:
                biomarker_list = []

            print(f"🔬 Extracted {len(biomarker_list)} biomarkers")

            if biomarker_list:
                formatted = _biomarkers_service.format_biomarkers_for_agent(biomarker_list)
                print(f"🔬 Formatted output:\n{formatted[:500]}...")
                return formatted
            else:
                return "No lab results found. You can upload medical reports through the app to see your lab data here."
        else:
            print("❌ API returned None or empty response")
            return "No lab results available yet. Upload a medical report to see your biomarker data."
    except Exception as e:
        print(f"❌ Error getting lab results: {e}")
        import traceback
        traceback.print_exc()
        return "Unable to retrieve lab results at this time."


@function_tool(description="Get detailed information about a specific biomarker. Call this when patient asks about a specific test like glucose, cholesterol, hemoglobin, etc. Use biomarker names like: glucose, ldl_cholesterol, hdl_cholesterol, total_cholesterol, triglycerides, hemoglobin, hba1c, vitamin_d, creatinine, etc.")
async def get_biomarker_detail(biomarker_name: str) -> str:
    """Fetch detailed information about a specific biomarker"""
    global _biomarkers_service
    print(f"🔬 Getting details for biomarker: {biomarker_name}")

    if not _biomarkers_service:
        return "Unable to fetch biomarker details - service not available."

    try:
        # Normalize the biomarker name (convert spaces to underscores, lowercase)
        normalized_name = biomarker_name.lower().replace(' ', '_').replace('-', '_')

        detail = await _biomarkers_service.get_biomarker_detail(normalized_name)

        if detail:
            formatted = _biomarkers_service.format_biomarker_detail_for_agent(detail)
            print(f"🔬 Retrieved details for {biomarker_name}")
            return formatted
        else:
            return f"I couldn't find information about {biomarker_name}. It may not be in your records yet. You can upload a medical report that includes this test."
    except Exception as e:
        print(f"❌ Error getting biomarker detail: {e}")
        return f"Unable to retrieve details for {biomarker_name} at this time."


@function_tool(description="Get health insights and recommendations based on the patient's lab results. Call this when patient asks about health concerns, what their results mean, or wants recommendations based on their labs.")
async def get_health_insights() -> str:
    """Fetch health insights based on biomarker data"""
    global _biomarkers_service
    print(f"💡 Fetching health insights...")

    if not _biomarkers_service:
        return "Unable to fetch health insights - service not available."

    try:
        insights_data = await _biomarkers_service.get_health_insights()

        if insights_data:
            formatted = _biomarkers_service.format_insights_for_agent(insights_data)
            insights_list = insights_data.get('insights', [])
            print(f"💡 Retrieved {len(insights_list)} health insights")
            return formatted
        else:
            return "No specific health insights at this time. Your lab results look good!"
    except Exception as e:
        print(f"❌ Error getting health insights: {e}")
        return "Unable to retrieve health insights at this time."


@function_tool(description="Get a summary of the patient's lab data including total biomarkers tracked, abnormal results count, and recent tests. Call this for a quick overview of lab status.")
async def get_labs_summary() -> str:
    """Fetch labs summary statistics"""
    global _biomarkers_service
    print(f"📊 Fetching labs summary...")

    if not _biomarkers_service:
        return "Unable to fetch labs summary - service not available."

    try:
        summary = await _biomarkers_service.get_labs_summary()

        if summary:
            total = summary.get('totalBiomarkers', 0)
            abnormal = summary.get('abnormalCount', 0)
            critical = summary.get('criticalCount', 0)
            recent = summary.get('recentTestsCount', 0)

            result = f"Lab Results Summary:\n"
            result += f"- Total biomarkers tracked: {total}\n"

            if critical > 0:
                result += f"- 🚨 Critical results: {critical} (requires attention)\n"
            if abnormal > 0:
                result += f"- ⚠️ Abnormal results: {abnormal}\n"
            if recent > 0:
                result += f"- Recent tests (last 30 days): {recent}\n"

            if critical == 0 and abnormal == 0 and total > 0:
                result += "✅ All your tracked biomarkers are within normal ranges!"

            return result
        else:
            return "No lab data available yet. Upload a medical report to start tracking your biomarkers."
    except Exception as e:
        print(f"❌ Error getting labs summary: {e}")
        return "Unable to retrieve labs summary at this time."


@function_tool(description="Get detailed medication history showing missed, late, and taken doses over a period. Use this to analyze medication adherence patterns, identify problematic medications, and correlate symptoms with missed or late doses. Period can be 'week' or 'month'.")
async def get_medication_history(period: str = "week") -> str:
    """Fetch detailed medication history with adherence analysis"""
    global _medication_service
    print(f"📋 Fetching medication history for {period}...")

    if not _medication_service:
        return "Unable to fetch medication history - service not available."

    try:
        history = await _medication_service.get_medication_history(period=period)

        if history:
            return _medication_service.format_medication_history_for_agent(history)
        else:
            return f"No medication history available for the past {period}."
    except Exception as e:
        print(f"❌ Error getting medication history: {e}")
        return "Unable to retrieve medication history at this time."


async def entrypoint(ctx: agents.JobContext):
    
    await ctx.connect()
    participant = await ctx.wait_for_participant() # Wait for the first remote participant
    print(f"Participant {participant.identity} joined. Starting voice assistant.")
    
    participant_metadata = json.loads(participant.metadata)
    
    print("participant_metadata info is: ", participant_metadata)

    patient_name = participant.name
    
    # Handle missing course data (when no active course exists)
    if 'course' in participant_metadata and participant_metadata['course']:
        patient_course_name = participant_metadata['course'].get("name", "No active course")
        patient_history = participant_metadata['course'].get("patient_history", "No history available")
        current_situation = participant_metadata['course'].get("current_situation", "No current situation")
        doctor_instructions = participant_metadata['course'].get("doctor_instructions", "No instructions available")
    else:
        patient_course_name = "No active course"
        patient_history = "No medical history available"
        current_situation = "General wellness check"
        doctor_instructions = "Please consult with your healthcare provider"
    
    medicines = participant_metadata.get('medicines', []) # this is list of medicines
    schedules = participant_metadata.get("schedules", []) # this is list of schedules
    next_schedules = participant_metadata.get("next_schedules", []) # this is list of next schedules
    current_time = participant_metadata.get("current_time", "")
    language = participant_metadata.get('language', 'en')
    agent_conversation_choice = participant_metadata.get('agent_conversation_choice', 'M')
    auth_token = participant_metadata.get("auth_token")

    # Debug: Log auth token status
    if auth_token:
        print(f"🔑 Auth token received: {auth_token[:20]}..." if len(auth_token) > 20 else f"🔑 Auth token: {auth_token}")
    else:
        print("❌ WARNING: No auth_token in participant metadata! API calls will fail.")

    # Get medical documents/reports (legacy)
    medical_documents = participant_metadata.get('medical_reports', [])

    # Set global variables for function tools
    global _medication_service, _observations_service, _biomarkers_service, _base_url, _auth_token
    _base_url = BASE_URL
    _auth_token = auth_token

    # Initialize observations service for saving patient observations
    _observations_service = ObservationsAPI(auth_token)
    print(f"📝 Observations service initialized")

    # Initialize biomarkers service for lab results access
    _biomarkers_service = BiomarkersAPI(auth_token, BASE_URL)
    print(f"🔬 Biomarkers service initialized with BASE_URL: {BASE_URL}")

    # Fetch medications directly from database
    print(f"🔄 Fetching medications from {BASE_URL}...")
    medication_service = get_medication_service(BASE_URL, auth_token)
    _medication_service = medication_service  # Store for function tools
    try:
        db_medications = await medication_service.get_medications(active_only=True)
    except Exception as e:
        print(f"❌ Error fetching medications: {e}")
        db_medications = None

    if db_medications:
        medicines_summary = medication_service.format_medications_for_agent(db_medications)
        print(f"💊 Loaded {len(db_medications)} medications from database")
    elif db_medications is not None and len(db_medications) == 0:
        # API succeeded but no medications registered
        medicines_summary = "No medications currently registered in your profile. You can add medications in the Medications tab of the app."
        print("ℹ️ No medications registered for this user")
    else:
        # API failed - do NOT use fallback metadata
        medicines_summary = "Unable to access your medication list at the moment. Please check your internet connection or try again later."
        print("❌ Failed to fetch medications from database - NO FALLBACK USED")

    # Fetch uploaded medical reports and pending recommendations from API
    medical_report_service = get_medical_report_service(BASE_URL, auth_token)
    user_id = participant_metadata.get('user_id') or participant.identity

    print(f"📋 Fetching medical reports for user: {user_id}")

    # Get latest report
    try:
        latest_report = await medical_report_service.get_latest_report(user_id)
    except Exception as e:
        print(f"❌ Error fetching latest report: {e}")
        latest_report = None

    # Get pending medication recommendations
    try:
        pending_recommendations = await medical_report_service.get_pending_recommendations(user_id)
    except Exception as e:
        print(f"❌ Error fetching pending recommendations: {e}")
        pending_recommendations = []

    # Format medical reports summary for agent
    medical_reports_summary = ""
    if latest_report:
        medical_reports_summary = medical_report_service.format_report_summary(latest_report)
        print(f"📄 Latest report: {latest_report.get('file_name')} - {len(pending_recommendations)} pending recommendations")
    elif medical_documents:
        # Fallback to legacy medical documents
        doc_summaries = []
        for doc in medical_documents:
            doc_info = f"- {doc.get('title', 'Untitled')}: {doc.get('document_type', 'Unknown type')}"
            if doc.get('is_parsed'):
                doc_info += " (AI analyzed)"
            if doc.get('description'):
                doc_info += f" - {doc.get('description')}"
            doc_summaries.append(doc_info)
        medical_reports_summary = "Medical Documents:\n" + "\n".join(doc_summaries)
    else:
        medical_reports_summary = "No medical reports uploaded yet. Patient can upload reports through the app."

    # Format pending recommendations
    pending_recommendations_summary = ""
    if pending_recommendations:
        pending_recommendations_summary = medical_report_service.format_recommendations_list(pending_recommendations)
        print(f"💊 {len(pending_recommendations)} pending medication recommendations")
        print(f"📋 Recommendations content:\n{pending_recommendations_summary}")
        # Debug: Print raw recommendation data
        for rec in pending_recommendations:
            print(f"   - {rec.get('medication_name', 'NO NAME')}: {rec.get('change_type', 'unknown')}")
    else:
        pending_recommendations_summary = "No pending medication changes from recent medical reports."

    # Fetch Apple Watch vitals from database
    watch_vitals_service = get_watch_vitals_service(BASE_URL, auth_token)
    try:
        watch_vitals = await watch_vitals_service.get_latest_vitals()
        watch_vitals_summary = watch_vitals_service.format_vitals_for_agent(watch_vitals)
    except Exception as e:
        print(f"❌ Error fetching watch vitals: {e}")
        watch_vitals = None
        watch_vitals_summary = "Unable to fetch Apple Watch vitals."

    if watch_vitals and not watch_vitals.get('is_demo'):
        print(f"⌚ Watch vitals loaded - HR: {watch_vitals.get('heart_rate')}bpm, SpO2: {watch_vitals.get('blood_oxygen')}%")
    else:
        print("⌚ No Watch vitals data available")

    print(f"⌚ Watch vitals summary for prompt:\n{watch_vitals_summary}")

    # Fetch user contacts (family, caregivers, emergency contacts)
    contacts_api = ContactsAPI(auth_token)
    try:
        contacts = await contacts_api.get_contacts()
        emergency_contacts = await contacts_api.get_emergency_contacts()
        contacts_summary = contacts_api.format_contacts_for_context(contacts) if contacts else "No contacts saved."
        emergency_contacts_summary = contacts_api.format_emergency_contacts_summary(emergency_contacts) if emergency_contacts else "No emergency contacts set up."
        print(f"👥 Loaded {len(contacts) if contacts else 0} contacts ({len(emergency_contacts) if emergency_contacts else 0} emergency)")
    except Exception as e:
        print(f"❌ Error fetching contacts: {e}")
        contacts_summary = "Unable to fetch contacts."
        emergency_contacts_summary = "Unable to fetch emergency contacts."

    print("patient_name is: ", patient_name)
    print("patient_course_name is: ", patient_course_name)
    print("patient_history is: ", patient_history)
    print("current_situation is: ", current_situation)
    print("doctor_instructions is: ", doctor_instructions)
    print("medicines is: ", medicines)
    print("schedules is: ", schedules)
    print("next_schedules is: ", next_schedules)
    print("current_time is: ", current_time)
    print("language is: ", language)
    print("agent_conversation_choice is: ", agent_conversation_choice)
    
    # Language configuration
    print(f"Configuring for language: {language}")
    
    # For Arabic (including Lebanese), use OpenAI Whisper and TTS
    if language in ['ar', 'ar-LB']:
        stt_engine = openai.STT(model="whisper-1", language="ar")
        # Voice selection based on dialect
        # Available voices: 'alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'
        # 'nova' - lighter, more natural female voice
        # 'shimmer' - softer, expressive female voice  
        # 'echo' - male voice with neutral accent
        if language == 'ar-LB':
            # For Lebanese Arabic, use shimmer for softer, more expressive tone
            voice_choice = "shimmer"
        else:
            # For standard Arabic, use nova
            voice_choice = "nova"
        
        tts_engine = openai.TTS(model="tts-1", voice=voice_choice)
        print(f"Using OpenAI Whisper for Arabic STT and OpenAI TTS with {voice_choice} voice")
    else:
        stt_engine = deepgram.STT(language=language)
        tts_engine = deepgram.TTS()
        print(f"Using Deepgram for {language}")
    
    # Define tools for the agent
    agent_tools = [
        mark_medication_taken,
        mark_medication_missed,
        get_current_medications,
        get_medication_status,
        report_side_effect,
        get_watch_vitals,
        # Observation tools for health tracking
        save_sleep_report,
        save_mood_report,
        save_symptom_report,
        save_energy_report,
        save_fall_report,
        save_general_observation,
        # Lab results and biomarker tools
        get_lab_results,
        get_biomarker_detail,
        get_health_insights,
        get_labs_summary,
        # Medication history and adherence analysis
        get_medication_history,
    ]
    print(f"🔧 Registering {len(agent_tools)} function tools with agent")
    for tool in agent_tools:
        print(f"   - {tool.__name__}")

    session = AgentSession(
        stt = stt_engine,
        llm=openai.LLM(model="gpt-4o-mini"),
        tts=tts_engine,
        vad=silero.VAD.load(),
        # turn_detection=MultilingualModel(),  # Disabled due to SDK compatibility issue
        tools=agent_tools,
    )


    # Add language instruction to the prompt
    language_instruction = ""
    if language == 'ar-LB':
        language_instruction = "\n\nCRITICAL: You MUST respond ONLY in Lebanese Arabic dialect. Examples:\n- Say 'كيفك' not 'كيف حالك'\n- Say 'شو' not 'ما' or 'ماذا'\n- Say 'هلق' not 'الآن'\n- Say 'مبلا' not 'بلى'\n- Say 'إيه' not 'نعم'\n- Use Lebanese words like: بدي، معليش، يعطيك العافية، شو فيك، وينك\nNEVER use formal Arabic (الفصحى). Speak like a Lebanese person would speak casually.\n"
    elif language == 'ar':
        language_instruction = "\n\nIMPORTANT: You MUST respond in Arabic. Use a friendly, conversational tone.\n"
    
    full_prompt = global_variables.agent_prompt.format(
        patient_name=patient_name,
        patient_course_name=patient_course_name,
        patient_history=patient_history,
        current_situation=current_situation,
        doctor_instructions=doctor_instructions,
        medicines=medicines_summary,
        schedules=schedules,
        next_schedules=next_schedules,
        current_time=current_time,
        medical_reports_summary=medical_reports_summary,
        pending_recommendations=pending_recommendations_summary,
        watch_vitals_summary=watch_vitals_summary,
        agent_conversation_choice=agent_conversation_choice,
        contacts_summary=contacts_summary,
        emergency_contacts=emergency_contacts_summary
    ) + language_instruction
    
    print("🚀 Starting agent session...")
    try:
        await session.start(
            room=ctx.room,
            agent=Assistant(full_prompt),
            room_input_options=RoomInputOptions(
                noise_cancellation=noise_cancellation.BVC(),
            ),
            room_output_options=RoomOutputOptions(
                audio_enabled=True,  # Ensure audio output is enabled
            ),
        )
        print("✅ Agent session started successfully")

        # Debug: Check if audio track is being published
        local_participant = ctx.room.local_participant
        print(f"🔊 Local participant: {local_participant.identity if local_participant else 'None'}")
        if local_participant:
            print(f"🔊 Audio tracks published: {len(local_participant.track_publications)}")
            for pub in local_participant.track_publications.values():
                print(f"   - Track: {pub.kind} - {pub.source} - muted: {pub.muted}")
    except Exception as e:
        print(f"❌ Failed to start agent session: {e}")
        raise

    async def write_transcript():
        current_date = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        epoch_time = int(datetime.datetime.now().timestamp())

        # Create user_logs directory if it doesn't exist
        os.makedirs("user_logs", exist_ok=True)

        filename = f"user_logs/transcript_{participant.identity}_{current_date}.json"
        item_data = session.history.to_dict()

        # Transform conversation data to Toon format
        # Toon: y=type, r=role, c=content, t=timestamp, id=identifier
        toon_messages = []
        if "items" in item_data:
            for i, item in enumerate(item_data["items"]):
                if item["type"] == "message":
                    role = item["role"]
                    content = " ".join(item["content"]) if isinstance(item["content"], list) else str(item["content"])

                    # Toon role codes: u=user, a=assistant, s=system
                    role_code = "a" if role == "assistant" else "u" if role == "user" else "s"

                    toon_messages.append({
                        "id": i + 1,
                        "y": "msg",
                        "r": role_code,
                        "c": content,
                        "t": epoch_time
                    })

        # Handle missing course data in transcript (Toon format)
        if 'course' in participant_metadata and participant_metadata['course']:
            course_detail = {
                "id": participant_metadata['course']["id"],
                "n": participant_metadata['course']["name"],  # n=name
                "s": schedules  # s=schedules
            }
        else:
            course_detail = {
                "id": None,
                "n": "No active course",
                "s": []
            }

        # Final Toon-formatted data
        final_data = {
            "msgs": toon_messages,  # Array of Toon messages
            "crs": course_detail,   # Course details
            "t": epoch_time,        # Session timestamp
            "uid": participant.identity  # User identifier
        }

        with open(filename, 'w') as f:
            json.dump(final_data, f, separators=(',', ':'))  # No whitespace for token efficiency
        print(f"✅ Transcript (Toon format) for {participant.identity} saved to {filename}")
        print(f"📊 Transcript contains {len(toon_messages)} messages")

        # Call upload after saving using the helper
        print(f"📤 Uploading transcript to {BASE_URL}/users/upload_json/...")

        if not participant_metadata.get("auth_token"):
            print("❌ Cannot upload transcript: No auth_token in metadata!")
            return

        try:
            upload_result = upload_json(filename, BASE_URL, participant_metadata["auth_token"], print_response)
            if upload_result:
                print("✅ Transcript uploaded to database successfully")
            else:
                print("❌ Transcript upload failed - check API response above")
        except Exception as e:
            print(f"❌ Exception during transcript upload: {e}")

    ctx.add_shutdown_callback(write_transcript)


    # Use appropriate greeting based on language
    if language in ['ar', 'ar-LB']:
        greeting_text = f"مرحبا {patient_name}، كيفك اليوم؟"  # Lebanese Arabic greeting
    else:
        greeting_text = f"{global_variables.greeting_msg_language.get(language, 'Hello')}, {patient_name}"
    
    print(f"🎤 Speaking greeting: {greeting_text}")
    try:
        await session.say(text=greeting_text, allow_interruptions=True)
        print("✅ Greeting spoken successfully")
    except Exception as e:
        print(f"❌ Failed to speak greeting: {e}")

    print("=" * 50)
    print("🤖 Agent is now listening and ready to respond")
    print("=" * 50)


if __name__ == "__main__":
    agents.cli.run_app(agents.WorkerOptions(
        entrypoint_fnc=entrypoint, 
        drain_timeout=10
    ))