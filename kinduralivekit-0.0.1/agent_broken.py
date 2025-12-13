import asyncio
import datetime
import os
from dotenv import load_dotenv
import json

from kindura_agent import KinduraAgent
import utils.global_variables as global_variables
from utils.global_variables import BASE_URL

from livekit import agents
from livekit.agents import AgentSession, RoomInputOptions

from livekit.plugins import (
    deepgram,
    noise_cancellation,
    silero,
    openai,
)
from livekit.plugins.turn_detector.multilingual import MultilingualModel
from utils.json_to_be import upload_json


def print_response(response, context):
    print(f"[{context}] Status: {response.status_code}, Response: {response.text}")


load_dotenv()


async def entrypoint(ctx: agents.JobContext):
    try:
        print("🚀 Starting Kindura agent...")
        await ctx.connect()
        print("✅ Connected to LiveKit room")
        
        participant = await ctx.wait_for_participant()  # Wait for the first remote participant
        print(f"✅ Participant {participant.identity} joined. Starting voice assistant.")

        # Safely parse metadata
        try:
            participant_metadata = json.loads(participant.metadata or "{}")
            print("✅ Metadata parsed successfully")
        except json.JSONDecodeError as e:
            print(f"⚠️ Metadata parsing error: {e}")
            participant_metadata = {}
        print("participant_metadata info is: ", participant_metadata)

        patient_name = participant.name or "there"

        # Handle missing course data (when no active course exists)
        if "course" in participant_metadata and participant_metadata["course"]:
            patient_course_name = participant_metadata["course"].get("name", "No active course")
            patient_history = participant_metadata["course"].get("patient_history", "No history available")
            current_situation = participant_metadata["course"].get("current_situation", "No current situation")
            doctor_instructions = participant_metadata["course"].get("doctor_instructions", "No instructions available")
        else:
            patient_course_name = "No active course"
            patient_history = "No medical history available"
            current_situation = "General wellness check"
            doctor_instructions = "Please consult with your healthcare provider"

        medicines = participant_metadata.get("medicines", [])             # list
        schedules = participant_metadata.get("schedules", [])             # list
        next_schedules = participant_metadata.get("next_schedules", [])   # list
        current_time = participant_metadata.get("current_time", "")
        language = participant_metadata.get("language", "en")
        agent_conversation_choice = participant_metadata.get("agent_conversation_choice", "M")  # optional / unused

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

        # Build patient context (after vars above are set)
        patient_ctx = {
            "name": patient_name,
            "course_name": patient_course_name,
            "history": patient_history,
            "current_situation": current_situation,
            "doctor_instructions": doctor_instructions,
            "medicines": medicines,
            "schedules": schedules,
            "next_schedules": next_schedules,
            "current_time": current_time,
        }

        # Language configuration (STT/TTS)
        print(f"Configuring for language: {language}")
        if language in ["ar", "ar-LB"]:
            stt_engine = openai.STT(model="whisper-1", language="ar")
            voice_choice = "shimmer" if language == "ar-LB" else "nova"
            tts_engine = openai.TTS(model="tts-1", voice=voice_choice)
            print(f"Using OpenAI Whisper for Arabic STT and OpenAI TTS with {voice_choice} voice")
        else:
            stt_engine = deepgram.STT(language=language)
            tts_engine = deepgram.TTS()
            print(f"Using Deepgram for {language}")

        session = AgentSession(
            stt=stt_engine,
            llm=openai.LLM(model="gpt-4o-mini"),
            tts=tts_engine,
            vad=silero.VAD.load(
                min_silence_duration=1.0,  # Wait 1 second of silence before ending turn
                min_speech_duration=0.5,   # Minimum speech duration to register
            ),
            turn_detection=MultilingualModel(
                min_endpointing_delay=0.5,  # Shorter delay before considering turn complete
                max_endpointing_delay=2.0,  # Maximum wait time
            ),
        )

        # Start the session with KinduraAgent
        timezone = participant_metadata.get("timezone", "Asia/Riyadh")
        await session.start(
            room=ctx.room,
            agent=KinduraAgent(
                timezone=timezone,
                language=language,   # "en" | "ar" | "ar-LB"
                patient_ctx=patient_ctx,
            ),
            room_input_options=RoomInputOptions(
                noise_cancellation=noise_cancellation.BVC(),
            ),
        )

        async def write_transcript():
            current_date = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

            # Create user_logs directory if it doesn't exist
            os.makedirs("user_logs", exist_ok=True)

            filename = f"user_logs/transcript_{participant.identity}_{current_date}.json"
            item_data = session.history.to_dict()

            # Transform conversation data to desired format
            conversation = {}
            if "items" in item_data:
                for i, item in enumerate(item_data["items"]):
                    if item["type"] == "message":
                        role = item["role"]
                        content = " ".join(item["content"]) if isinstance(item["content"], list) else str(item["content"])

                        if role == "assistant":
                            conversation[f"ai_{i+1}"] = content
                        elif role == "user":
                            conversation[f"human_{i+1}"] = content

            # Handle missing course data in transcript
            if "course" in participant_metadata and participant_metadata["course"]:
                course_detail = {
                    "course_id": participant_metadata["course"].get("id"),
                    "course_name": participant_metadata["course"].get("name"),
                    "course_schedule": schedules,
                }
            else:
                course_detail = {
                    "course_id": None,
                    "course_name": "No active course",
                    "course_schedule": [],
                }

            final_data = {
                "conversation": conversation,
                "course_detail": course_detail,
            }

            with open(filename, "w") as f:
                json.dump(final_data, f, indent=2)
            print(f"Transcript for {participant.identity} saved to {filename}")

            # Upload if token available
            print("the filename is: ", filename)
            auth_token = participant_metadata.get("auth_token")
            if auth_token:
                upload_json(filename, BASE_URL, auth_token, print_response)
            else:
                print("No auth_token in metadata; skipping upload_json.")

        ctx.add_shutdown_callback(write_transcript)

        # Use appropriate greeting based on language
        if language in ["ar", "ar-LB"]:
            greeting_text = f"مرحبا {patient_name}، كيفك اليوم؟"  # Lebanese Arabic greeting
        else:
            greeting_text = f"{global_variables.greeting_msg_language.get(language, 'Hello')}, {patient_name}"

        # Wait a moment for client to be ready for audio
        await asyncio.sleep(1.0)
        
        print(f"Speaking greeting: {greeting_text}")
        await session.say(text=greeting_text, allow_interruptions=True)
        print("✅ Greeting spoken successfully - Agent is ready!")

    except Exception as e:
        print(f"❌ CRITICAL ERROR in agent: {str(e)}")
        print(f"❌ Error type: {type(e).__name__}")
        import traceback
        print(f"❌ Full traceback:\n{traceback.format_exc()}")
        raise  # Re-raise to ensure proper error handling


if __name__ == "__main__":
    agents.cli.run_app(
        agents.WorkerOptions(
            entrypoint_fnc=entrypoint,
            drain_timeout=10,
        )
    )
