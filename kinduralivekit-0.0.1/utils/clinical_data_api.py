"""
Clinical Data API Service for Kindura LiveKit Agent
====================================================
Following Reports.md Specification for Parkinson's Disease Monitoring

This service provides methods for:
- Collecting motor symptoms (daily)
- Collecting non-motor symptoms (weekly)
- Recording safety events
- Getting data gaps (what questions to ask)
- Submitting individual symptom values

Data Collection Rules (per Reports.md):
- One symptom per question
- <= 12 words per prompt
- Numeric scales (1-5) preferred
- Plain language only
- No diagnostic phrasing
"""

import aiohttp
import json
from datetime import datetime


class ClinicalDataAPI:
    """API client for clinical data collection endpoints"""

    def __init__(self, auth_token: str, base_url: str):
        self.auth_token = auth_token
        self.base_url = base_url.rstrip('/')
        self.headers = {
            'Authorization': f'Token {auth_token}',
            'Content-Type': 'application/json'
        }

    async def get_data_gaps(self) -> list:
        """
        Get list of data gaps (missing data points) for the agent to collect.
        Returns prioritized list of prompts to ask the patient.
        """
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.base_url}/agent/data-gaps/",
                    headers=self.headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', [])
                    else:
                        print(f"Error fetching data gaps: {response.status}")
                        return []
        except Exception as e:
            print(f"Exception in get_data_gaps: {e}")
            return []

    async def collect_symptom(
        self,
        symptom_type: str,
        value: int,
        laterality_value: str = None,
        data_source: str = 'patient',
        notes: str = ''
    ) -> dict:
        """
        Submit a single symptom value collected from the patient.

        Args:
            symptom_type: One of: bradykinesia, tremor, rigidity, gait, laterality,
                         sleep, constipation, mood, fatigue, dizziness, smell
            value: 1-5 scale (1=minimal, 5=severe)
            laterality_value: For laterality only - 'L', 'R', or 'B'
            data_source: patient, caregiver, device, or inferred
            notes: Optional notes
        """
        try:
            payload = {
                'symptom_type': symptom_type,
                'value': value,
                'data_source': data_source
            }
            if laterality_value:
                payload['laterality_value'] = laterality_value
            if notes:
                payload['notes'] = notes

            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/agent/collect-symptom/",
                    headers=self.headers,
                    json=payload
                ) as response:
                    if response.status in [200, 201]:
                        data = await response.json()
                        return {'success': True, 'result': data.get('result')}
                    else:
                        error_text = await response.text()
                        print(f"Error collecting symptom: {response.status} - {error_text}")
                        return {'success': False, 'error': error_text}
        except Exception as e:
            print(f"Exception in collect_symptom: {e}")
            return {'success': False, 'error': str(e)}

    async def record_safety_event(
        self,
        event_type: str,
        description: str,
        severity: str = 'medium',
        injury_sustained: bool = False
    ) -> dict:
        """
        Record a safety event (fall, hallucination, rapid worsening, etc.)

        Args:
            event_type: fall, hallucination, rapid_worsening, autonomic_severe,
                       poor_levodopa_response, other
            description: Description of the event
            severity: low, medium, high, critical
            injury_sustained: Whether injury occurred (for falls)
        """
        try:
            payload = {
                'event_type': event_type,
                'description': description,
                'severity': severity,
                'occurred_at': datetime.now().isoformat(),
                'injury_sustained': injury_sustained,
                'data_source': 'patient'
            }

            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/clinical/safety-events/",
                    headers=self.headers,
                    json=payload
                ) as response:
                    if response.status in [200, 201]:
                        data = await response.json()
                        return {'success': True, 'result': data.get('result')}
                    else:
                        error_text = await response.text()
                        print(f"Error recording safety event: {response.status}")
                        return {'success': False, 'error': error_text}
        except Exception as e:
            print(f"Exception in record_safety_event: {e}")
            return {'success': False, 'error': str(e)}

    async def get_motor_symptoms(self, days: int = 7) -> list:
        """Get recent motor symptom entries"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.base_url}/clinical/motor-symptoms/?days={days}",
                    headers=self.headers
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', [])
                    return []
        except Exception as e:
            print(f"Exception in get_motor_symptoms: {e}")
            return []

    async def get_clinical_reports(self, report_type: str = None, limit: int = 5) -> list:
        """Get clinical reports (daily, weekly, monthly)"""
        try:
            url = f"{self.base_url}/clinical/reports/?limit={limit}"
            if report_type:
                url += f"&type={report_type}"

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=self.headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', [])
                    return []
        except Exception as e:
            print(f"Exception in get_clinical_reports: {e}")
            return []

    def format_data_gaps_for_agent(self, gaps: list) -> str:
        """Format data gaps as a prompt guide for the agent"""
        if not gaps:
            return "All required data has been collected for today."

        result = "Data Collection Needed:\n"
        for gap in gaps:
            result += f"- {gap.get('prompt', 'No prompt')} "
            result += f"(Priority: {gap.get('priority', 5)}, "
            result += f"Overdue: {gap.get('days_overdue', 0)} days)\n"

        return result

    def format_motor_symptoms_for_agent(self, symptoms: list) -> str:
        """Format motor symptoms for agent context"""
        if not symptoms:
            return "No motor symptom data recorded recently."

        result = "Recent Motor Symptom Trends:\n"
        for entry in symptoms[:7]:  # Last 7 days
            date = entry.get('recorded_date', 'Unknown')
            brady = entry.get('bradykinesia', 'N/A')
            tremor = entry.get('tremor', 'N/A')
            rigidity = entry.get('rigidity', 'N/A')
            gait = entry.get('gait_difficulty', 'N/A')
            lat = entry.get('laterality', 'N/A')

            result += f"- {date}: Bradykinesia={brady}, Tremor={tremor}, "
            result += f"Rigidity={rigidity}, Gait={gait}, Side={lat}\n"

        return result


def get_clinical_data_service(base_url: str, auth_token: str) -> ClinicalDataAPI:
    """Factory function to create ClinicalDataAPI instance"""
    return ClinicalDataAPI(auth_token=auth_token, base_url=base_url)
