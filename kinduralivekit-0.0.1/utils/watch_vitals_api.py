"""
Watch Vitals API Service for LiveKit Agent
Fetches Apple Watch health data from Django API
"""
import aiohttp
from datetime import datetime


class WatchVitalsService:
    def __init__(self, base_url: str, auth_token: str):
        self.base_url = base_url.rstrip('/')
        self.auth_token = auth_token
        self.headers = {
            'Authorization': f'Token {auth_token}',
            'Content-Type': 'application/json'
        }

    async def get_latest_vitals(self) -> dict:
        """Get the most recent Watch vitals for the user"""
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.base_url}/watch-vitals/"
                print(f"📡 Fetching watch vitals from: {url}")
                async with session.get(url, headers=self.headers) as response:
                    print(f"⌚ Watch vitals API response status: {response.status}")
                    if response.status == 200:
                        data = await response.json()
                        print(f"⌚ Watch vitals API response: {data}")
                        if data.get('status') and data.get('result'):
                            result = data['result']
                            # Log what we received
                            if result.get('is_demo'):
                                print("⌚ Received demo vitals data (no real Watch data)")
                            else:
                                print(f"⌚ Real vitals: HR={result.get('heart_rate')}bpm, SpO2={result.get('blood_oxygen')}%, Sleep={result.get('sleep_hours')}h")
                                if result.get('last_updated'):
                                    print(f"⌚ Last updated: {result.get('last_updated')}")
                            return result
                        else:
                            print(f"⌚ API returned status=false or no result: {data}")
                    else:
                        response_text = await response.text()
                        print(f"❌ Failed to get watch vitals: {response.status} - {response_text}")
                    return None
        except Exception as e:
            print(f"❌ Error fetching watch vitals: {e}")
            import traceback
            traceback.print_exc()
            return None

    async def get_vitals_history(self, days: int = 7) -> list:
        """Get Watch vitals history for the past N days"""
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.base_url}/watch-vitals/history/?days={days}"
                async with session.get(url, headers=self.headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        if data.get('status') and data.get('result'):
                            return data['result']
                    return []
        except Exception as e:
            print(f"Error fetching watch vitals history: {e}")
            return []

    def format_vitals_for_agent(self, vitals: dict) -> str:
        """Format Watch vitals data for agent prompt - comprehensive health data"""
        if not vitals:
            return "No Apple Watch data available."

        # Check if demo data
        is_demo = vitals.get('is_demo', False)
        if is_demo:
            return "No Apple Watch data synced yet. Patient has not connected their Apple Watch."

        # === VITAL SIGNS ===
        heart_rate = vitals.get('heart_rate', 0)
        blood_oxygen = vitals.get('blood_oxygen', 0)
        hrv = vitals.get('hrv', 0)
        respiratory_rate = vitals.get('respiratory_rate', 0)

        # === SLEEP DATA ===
        sleep_hours = vitals.get('sleep_hours', vitals.get('total_sleep_hours', 0))
        sleep_score = vitals.get('sleep_score', 0)
        deep_sleep = vitals.get('deep_sleep_hours', 0)
        rem_sleep = vitals.get('rem_sleep_hours', 0)
        core_sleep = vitals.get('core_sleep_hours', 0)
        awake_hours = vitals.get('awake_hours', vitals.get('awake_time_hours', 0))
        awakenings = vitals.get('awakenings', vitals.get('awakenings_count', 0))
        sleep_quality = vitals.get('sleep_quality', 'unknown')

        # === ACTIVITY DATA ===
        steps = vitals.get('steps', 0)
        calories = vitals.get('calories', 0)
        distance_km = vitals.get('distance_km', 0)
        exercise_minutes = vitals.get('exercise_minutes', 0)
        floors_climbed = vitals.get('floors_climbed', 0)
        stand_minutes = vitals.get('stand_minutes', 0)

        # === FALLS ===
        falls_count = vitals.get('falls_count', 0)
        fall_detected = vitals.get('fall_detected', False)

        last_updated = vitals.get('last_updated', vitals.get('recorded_at'))

        # Determine health status and alerts
        alerts = []

        # Heart rate analysis
        heart_status = "normal"
        if heart_rate < 50:
            heart_status = "LOW (bradycardia)"
            alerts.append(f"Low heart rate detected: {heart_rate} bpm")
        elif heart_rate > 100:
            heart_status = "HIGH (tachycardia)"
            alerts.append(f"Elevated heart rate detected: {heart_rate} bpm")

        # Blood oxygen analysis
        oxygen_status = "normal"
        if blood_oxygen > 0 and blood_oxygen < 95:
            oxygen_status = "LOW"
            alerts.append(f"Low blood oxygen: {blood_oxygen}%")

        # Sleep analysis
        if sleep_hours > 0 and sleep_hours < 6:
            alerts.append(f"Insufficient sleep: only {sleep_hours:.1f} hours")
        if awakenings > 4:
            alerts.append(f"Fragmented sleep: {awakenings} awakenings")

        # Fall detection
        if fall_detected:
            alerts.append("URGENT: Recent fall detected!")
        elif falls_count > 0:
            alerts.append(f"Note: {falls_count} fall(s) recorded recently")

        # Build comprehensive summary
        summary = "Apple Watch Health Data:\n\n"

        # Vital Signs Section
        summary += "VITAL SIGNS:\n"
        summary += f"Heart Rate: {heart_rate:.0f} beats per minute, {heart_status}\n"
        summary += f"Blood Oxygen: {blood_oxygen:.0f} percent, {oxygen_status}\n"
        if hrv > 0:
            summary += f"Heart Rate Variability: {hrv:.0f} milliseconds\n"
        if respiratory_rate > 0:
            summary += f"Respiratory Rate: {respiratory_rate:.1f} breaths per minute\n"

        # Sleep Section
        summary += "\nSLEEP (Last Night):\n"
        if sleep_hours > 0:
            summary += f"Total Sleep: {sleep_hours:.1f} hours\n"
            if sleep_score > 0:
                summary += f"Sleep Score: {sleep_score} out of 100\n"
            summary += f"Sleep Quality: {sleep_quality}\n"
            if deep_sleep > 0 or rem_sleep > 0 or core_sleep > 0:
                summary += f"Sleep Stages: Deep {deep_sleep:.1f}h, REM {rem_sleep:.1f}h, Core {core_sleep:.1f}h, Awake {awake_hours:.1f}h\n"
            if awakenings > 0:
                summary += f"Awakenings: {awakenings} times\n"
        else:
            summary += "No sleep data recorded\n"

        # Activity Section
        summary += "\nACTIVITY (Today):\n"
        if steps > 0:
            summary += f"Steps: {steps:,}\n"
        if calories > 0:
            summary += f"Calories Burned: {calories} kcal\n"
        if distance_km > 0:
            summary += f"Distance: {distance_km:.1f} kilometers\n"
        if exercise_minutes > 0:
            summary += f"Exercise: {exercise_minutes} minutes\n"
        if floors_climbed > 0:
            summary += f"Floors Climbed: {floors_climbed}\n"
        if stand_minutes > 0:
            summary += f"Standing Time: {stand_minutes} minutes\n"
        if steps == 0 and calories == 0:
            summary += "No activity data recorded yet\n"

        # Falls Section
        summary += "\nFALLS:\n"
        if fall_detected:
            summary += "Recent fall detected - check on patient!\n"
        elif falls_count > 0:
            summary += f"{falls_count} fall(s) recorded\n"
        else:
            summary += "No falls detected\n"

        if last_updated:
            try:
                dt = datetime.fromisoformat(str(last_updated).replace('Z', '+00:00'))
                summary += f"\nLast Updated: {dt.strftime('%B %d, %Y at %I:%M %p')}"
            except:
                pass

        if alerts:
            summary += "\n\nHEALTH ALERTS:\n" + "\n".join([f"- {alert}" for alert in alerts])

        return summary

    def format_vitals_history_for_agent(self, history: list) -> str:
        """Format vitals history as trends for the agent"""
        if not history:
            return ""

        # Calculate averages and trends
        heart_rates = [v.get('heart_rate', 0) for v in history if v.get('heart_rate')]
        sleep_hours = [v.get('total_sleep_hours', 0) for v in history if v.get('total_sleep_hours')]
        falls = sum(1 for v in history if v.get('fall_detected'))

        if not heart_rates:
            return ""

        avg_hr = sum(heart_rates) / len(heart_rates)
        avg_sleep = sum(sleep_hours) / len(sleep_hours) if sleep_hours else 0

        return f"""
Weekly Health Trends:
- Average Heart Rate: {avg_hr:.0f} bpm
- Average Sleep: {avg_sleep:.1f} hours/night
- Total Falls This Week: {falls}
- Data Points: {len(history)} readings"""


def get_watch_vitals_service(base_url: str, auth_token: str) -> WatchVitalsService:
    """Factory function to create WatchVitalsService instance"""
    return WatchVitalsService(base_url, auth_token)
