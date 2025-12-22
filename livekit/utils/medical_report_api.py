"""
Medical Report API Service for LiveKit Agent
Handles communication with Django backend for medical report data
"""

import os
import aiohttp
import json
from typing import List, Dict, Optional, Any
from datetime import datetime


class MedicalReportAPIService:
    """Service to interact with Django medical reports API"""

    def __init__(self, base_url: str = None, api_token: str = None):
        self.base_url = base_url or os.getenv('DJANGO_API_URL', 'http://localhost:8000/api')
        self.api_token = api_token
        self.headers = {}
        if self.api_token:
            self.headers['Authorization'] = f'Token {self.api_token}'

    async def _make_request(
        self,
        method: str,
        endpoint: str,
        data: Dict = None,
        params: Dict = None
    ) -> Optional[Dict]:
        """Make HTTP request to Django API"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"

        try:
            async with aiohttp.ClientSession() as session:
                async with session.request(
                    method,
                    url,
                    headers=self.headers,
                    json=data,
                    params=params
                ) as response:
                    if response.status in [200, 201]:
                        return await response.json()
                    else:
                        print(f"❌ API Error: {response.status} - {await response.text()}")
                        return None
        except Exception as e:
            print(f"❌ Request failed: {str(e)}")
            return None

    async def get_user_reports(self, user_id: str) -> List[Dict]:
        """
        Fetch all medical reports for a user

        Returns:
            List of report objects with: id, file_name, status, uploaded_at,
            pending_recommendations_count, etc.
        """
        response = await self._make_request(
            'GET',
            f'uploaded-reports/',
            params={'user': user_id}
        )

        if response and response.get('status'):
            return response.get('results', [])
        return []

    async def get_latest_report(self, user_id: str) -> Optional[Dict]:
        """
        Get most recent medical report with full details

        Returns:
            Report object with recommendations and biomarkers
        """
        response = await self._make_request(
            'GET',
            'uploaded-reports/latest/',
            params={'user': user_id}
        )

        if response and response.get('status'):
            return response.get('result')
        return None

    async def get_report_details(self, report_id: str) -> Optional[Dict]:
        """Get detailed information about a specific report"""
        response = await self._make_request(
            'GET',
            f'uploaded-reports/{report_id}/'
        )

        if response and response.get('status'):
            return response.get('result')
        return None

    async def get_pending_recommendations(self, user_id: str) -> List[Dict]:
        """
        Get all pending medication recommendations for user

        Returns:
            List of recommendations with: medication_name, change_type,
            old_value, new_value, reason, priority, etc.
        """
        response = await self._make_request(
            'GET',
            'medication-recommendations/pending/',
            params={'user': user_id}
        )

        if response and response.get('status'):
            return response.get('result', [])
        return []

    async def apply_recommendation(
        self,
        recommendation_id: str,
        medicine_id: str = None
    ) -> bool:
        """
        Mark a recommendation as applied

        Args:
            recommendation_id: ID of the recommendation
            medicine_id: Optional ID of the medicine it was applied to

        Returns:
            True if successful
        """
        data = {}
        if medicine_id:
            data['medicine_id'] = medicine_id

        response = await self._make_request(
            'POST',
            f'medication-recommendations/{recommendation_id}/apply/',
            data=data
        )

        return response and response.get('status')

    async def dismiss_recommendation(
        self,
        recommendation_id: str,
        reason: str = None
    ) -> bool:
        """
        Dismiss a recommendation

        Args:
            recommendation_id: ID of the recommendation
            reason: Optional reason for dismissal

        Returns:
            True if successful
        """
        data = {}
        if reason:
            data['reason'] = reason

        response = await self._make_request(
            'POST',
            f'medication-recommendations/{recommendation_id}/dismiss/',
            data=data
        )

        return response and response.get('status')

    async def get_user_biomarkers(
        self,
        user_id: str,
        biomarker_name: str = None,
        date_from: str = None,
        date_to: str = None
    ) -> List[Dict]:
        """
        Get biomarker data for user

        Args:
            user_id: User ID
            biomarker_name: Optional filter by biomarker name
            date_from: Optional start date (YYYY-MM-DD)
            date_to: Optional end date (YYYY-MM-DD)

        Returns:
            List of biomarker readings
        """
        params = {'user': user_id}
        if biomarker_name:
            params['name'] = biomarker_name
        if date_from:
            params['date_from'] = date_from
        if date_to:
            params['date_to'] = date_to

        response = await self._make_request(
            'GET',
            'biomarkers/user/',
            params=params
        )

        if response and response.get('status'):
            return response.get('result', [])
        return []

    async def get_biomarker_trends(
        self,
        user_id: str,
        biomarker_name: str
    ) -> List[Dict]:
        """
        Get historical trend for a specific biomarker

        Returns:
            List of biomarker readings over time
        """
        response = await self._make_request(
            'GET',
            f'biomarkers/trends/{biomarker_name}/',
            params={'user': user_id}
        )

        if response and response.get('status'):
            return response.get('result', [])
        return []

    def format_report_summary(self, report: Dict) -> str:
        """
        Format a report into a conversational summary

        Args:
            report: Report object from API

        Returns:
            Human-readable summary string
        """
        if not report:
            return "I couldn't retrieve the report details."

        summary_parts = []

        # Basic info
        file_name = report.get('file_name', 'Unknown')
        uploaded_at = report.get('uploaded_at', '')
        if uploaded_at:
            try:
                date_obj = datetime.fromisoformat(uploaded_at.replace('Z', '+00:00'))
                uploaded_at = date_obj.strftime('%B %d, %Y')
            except:
                pass

        summary_parts.append(f"I've reviewed your medical report '{file_name}' uploaded on {uploaded_at}.")

        # Doctor's notes
        doctor_notes = report.get('doctor_notes', '')
        if doctor_notes:
            summary_parts.append(f"\nDoctor's Notes: {doctor_notes}")

        # Diagnoses
        diagnoses = report.get('diagnoses', [])
        if diagnoses:
            summary_parts.append(f"\nDiagnoses: {', '.join(diagnoses)}")

        # Biomarkers summary
        biomarkers = report.get('extracted_biomarkers', [])
        if biomarkers:
            out_of_range = [b for b in biomarkers if b.get('is_out_of_range')]
            if out_of_range:
                summary_parts.append(f"\n⚠️ {len(out_of_range)} biomarker(s) are out of normal range:")
                for biomarker in out_of_range[:3]:  # Show top 3
                    name = biomarker['name']
                    value = biomarker['value']
                    unit = biomarker['unit']
                    flag = biomarker.get('flag', '')
                    summary_parts.append(f"  • {name}: {value} {unit} ({flag})")

        # Medication recommendations
        recommendations = report.get('recommendations', [])
        pending_recs = [r for r in recommendations if r.get('status') == 'pending']

        if pending_recs:
            summary_parts.append(f"\n💊 Medication Changes ({len(pending_recs)} pending):")
            for rec in pending_recs:
                change_type = rec['change_type']
                med_name = rec['medication_name']

                if change_type == 'new':
                    dosage = rec['new_value'].get('dosage', '')
                    frequency = rec['new_value'].get('frequency', '')
                    summary_parts.append(f"  • Start new medication: {med_name} - {dosage}, {frequency}")

                elif change_type == 'dosage_change':
                    old_dosage = rec.get('old_value', {}).get('dosage', 'current dose')
                    new_dosage = rec['new_value'].get('dosage', '')
                    summary_parts.append(f"  • Change {med_name} from {old_dosage} to {new_dosage}")

                elif change_type == 'schedule_change':
                    old_freq = rec.get('old_value', {}).get('frequency', 'current schedule')
                    new_freq = rec['new_value'].get('frequency', '')
                    summary_parts.append(f"  • Update {med_name} from {old_freq} to {new_freq}")

                elif change_type == 'discontinue':
                    summary_parts.append(f"  • Stop taking {med_name}")

                # Include reason if available
                reason = rec.get('reason')
                if reason:
                    summary_parts.append(f"    Reason: {reason}")

            summary_parts.append("\nWould you like me to help you update your medication schedule?")

        return "\n".join(summary_parts)

    def format_recommendations_list(self, recommendations: List[Dict]) -> str:
        """
        Format list of recommendations into conversational text

        Returns:
            Human-readable list of recommendations
        """
        if not recommendations:
            return "You don't have any pending medication changes."

        summary = f"You have {len(recommendations)} pending medication change(s):\n\n"

        for i, rec in enumerate(recommendations, 1):
            med_name = rec['medication_name']
            change_type = rec['change_type']

            summary += f"{i}. {med_name}: "

            if change_type == 'new':
                dosage = rec['new_value'].get('dosage', '')
                frequency = rec['new_value'].get('frequency', '')
                summary += f"Start new - {dosage}, {frequency}"

            elif change_type == 'dosage_change':
                old_dosage = rec.get('old_value', {}).get('dosage', 'current')
                new_dosage = rec['new_value'].get('dosage', '')
                summary += f"Change dose from {old_dosage} to {new_dosage}"

            elif change_type == 'schedule_change':
                new_freq = rec['new_value'].get('frequency', '')
                summary += f"Change schedule to {new_freq}"

            elif change_type == 'discontinue':
                summary += "Discontinue"

            # Add urgency indicator
            if rec.get('is_urgent'):
                summary += " ⚠️ URGENT"

            summary += "\n"

        summary += "\nWould you like to review these changes?"

        return summary


# Singleton instance
_medical_report_service = None


def get_medical_report_service(base_url: str = None, api_token: str = None) -> MedicalReportAPIService:
    """Get or create the medical report service singleton"""
    global _medical_report_service
    if _medical_report_service is None:
        _medical_report_service = MedicalReportAPIService(base_url, api_token)
    return _medical_report_service
