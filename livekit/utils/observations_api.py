"""
Observations API module for LiveKit agent.
Saves patient observations (symptoms, mood, sleep, side effects, etc.) to the database
for inclusion in daily/weekly/monthly reports.
"""
import os
import httpx
from typing import Optional, Dict, Any, List
from datetime import datetime

# Get base URL from environment or use default
BACKEND_URL = os.getenv("API_BASE_URL", "http://localhost:8000/api")


class ObservationsAPI:
    """API client for saving patient observations"""

    OBSERVATION_TYPES = [
        'medication',
        'sleep',
        'mood',
        'symptom',
        'side_effect',
        'fall',
        'pain',
        'energy',
        'appetite',
        'vital',
        'general',
    ]

    SEVERITY_LEVELS = ['normal', 'mild', 'moderate', 'severe', 'critical']

    def __init__(self, auth_token: str):
        self.auth_token = auth_token
        self.base_url = BACKEND_URL

    async def save_observation(
        self,
        observation_type: str,
        title: str,
        description: str,
        severity: str = 'normal',
        value: Optional[str] = None,
        medication_id: Optional[int] = None,
        conversation_id: Optional[str] = None,
        ai_insight: Optional[str] = None,
        concern_level: int = 0,
        requires_attention: bool = False,
        source: str = 'voice'
    ) -> Optional[Dict[str, Any]]:
        """
        Save a patient observation to the database.

        Args:
            observation_type: Type of observation (medication, sleep, mood, etc.)
            title: Brief description/title of the observation
            description: Detailed description
            severity: normal, mild, moderate, severe, critical
            value: Optional value (e.g., "7 hours", "good", "5/10")
            medication_id: Related medication ID if applicable
            conversation_id: ID of the conversation where this was observed
            ai_insight: AI-generated insight about the observation
            concern_level: 0-10 scale of concern
            requires_attention: Flag for doctor review
            source: voice, app, or sensor

        Returns:
            Created observation data or None if error
        """
        if observation_type not in self.OBSERVATION_TYPES:
            print(f"⚠️ Unknown observation type: {observation_type}, using 'general'")
            observation_type = 'general'

        if severity not in self.SEVERITY_LEVELS:
            print(f"⚠️ Unknown severity level: {severity}, using 'normal'")
            severity = 'normal'

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    f"{self.base_url}/users/save_observation/",
                    headers={"Authorization": f"Token {self.auth_token}"},
                    json={
                        'type': observation_type,
                        'title': title,
                        'description': description,
                        'severity': severity,
                        'value': value,
                        'medication_id': medication_id,
                        'conversation_id': conversation_id,
                        'ai_insight': ai_insight,
                        'concern_level': concern_level,
                        'requires_attention': requires_attention,
                        'source': source,
                    }
                )

                if response.status_code in [200, 201]:
                    data = response.json()
                    if data.get('status'):
                        print(f"✅ Saved observation: {observation_type} - {title}")
                        return data.get('result')
                    return None
                else:
                    print(f"❌ Failed to save observation: {response.status_code}")
                    return None
        except Exception as e:
            print(f"❌ Error saving observation: {e}")
            return None

    async def save_medication_observation(
        self,
        medication_name: str,
        action: str,  # 'taken', 'missed', 'late', 'skipped'
        notes: Optional[str] = None,
        medication_id: Optional[int] = None,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a medication-related observation"""
        title = f"Medication {action}: {medication_name}"
        description = notes or f"Patient {action} their {medication_name}."
        severity = 'normal' if action == 'taken' else 'mild'

        return await self.save_observation(
            observation_type='medication',
            title=title,
            description=description,
            severity=severity,
            value=action,
            medication_id=medication_id,
            conversation_id=conversation_id,
        )

    async def save_side_effect(
        self,
        medication_name: str,
        symptom: str,
        severity: str = 'mild',
        medication_id: Optional[int] = None,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a side effect observation"""
        title = f"Side effect: {symptom} (from {medication_name})"
        description = f"Patient reported {symptom} after taking {medication_name}."

        # Set requires_attention for moderate+ severity
        requires_attention = severity in ['moderate', 'severe', 'critical']
        concern_level = {'normal': 0, 'mild': 2, 'moderate': 5, 'severe': 8, 'critical': 10}.get(severity, 0)

        return await self.save_observation(
            observation_type='side_effect',
            title=title,
            description=description,
            severity=severity,
            value=symptom,
            medication_id=medication_id,
            conversation_id=conversation_id,
            requires_attention=requires_attention,
            concern_level=concern_level,
        )

    async def save_sleep_observation(
        self,
        hours: Optional[float] = None,
        quality: Optional[str] = None,  # 'good', 'fair', 'poor'
        notes: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a sleep observation"""
        title = "Sleep report"
        description_parts = []

        if hours is not None:
            description_parts.append(f"Patient slept {hours} hours.")
        if quality:
            description_parts.append(f"Sleep quality: {quality}.")
        if notes:
            description_parts.append(notes)

        description = " ".join(description_parts) or "Patient reported sleep status."

        # Determine severity based on hours and quality
        severity = 'normal'
        if hours is not None:
            if hours < 5:
                severity = 'moderate'
            elif hours < 6:
                severity = 'mild'
        if quality == 'poor':
            severity = 'moderate' if severity == 'normal' else severity

        value = f"{hours}h" if hours else quality

        return await self.save_observation(
            observation_type='sleep',
            title=title,
            description=description,
            severity=severity,
            value=value,
            conversation_id=conversation_id,
        )

    async def save_mood_observation(
        self,
        mood: str,  # 'good', 'okay', 'sad', 'anxious', 'stressed', etc.
        notes: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a mood observation"""
        title = f"Mood: {mood}"
        description = notes or f"Patient reported feeling {mood}."

        # Determine severity based on mood
        negative_moods = ['sad', 'anxious', 'stressed', 'depressed', 'irritable', 'angry']
        severity = 'mild' if mood.lower() in negative_moods else 'normal'

        requires_attention = mood.lower() in ['depressed', 'very sad', 'hopeless']

        return await self.save_observation(
            observation_type='mood',
            title=title,
            description=description,
            severity=severity,
            value=mood,
            conversation_id=conversation_id,
            requires_attention=requires_attention,
        )

    async def save_symptom_observation(
        self,
        symptom: str,
        severity: str = 'mild',
        notes: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a symptom observation"""
        title = f"Symptom: {symptom}"
        description = notes or f"Patient reported experiencing {symptom}."

        requires_attention = severity in ['moderate', 'severe', 'critical']
        concern_level = {'normal': 0, 'mild': 2, 'moderate': 5, 'severe': 8, 'critical': 10}.get(severity, 0)

        return await self.save_observation(
            observation_type='symptom',
            title=title,
            description=description,
            severity=severity,
            value=symptom,
            conversation_id=conversation_id,
            requires_attention=requires_attention,
            concern_level=concern_level,
        )

    async def save_energy_observation(
        self,
        level: str,  # 'high', 'normal', 'low', 'very low'
        notes: Optional[str] = None,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save an energy level observation"""
        title = f"Energy: {level}"
        description = notes or f"Patient reported {level} energy level."

        severity = 'normal'
        if level.lower() in ['low', 'tired']:
            severity = 'mild'
        elif level.lower() in ['very low', 'exhausted']:
            severity = 'moderate'

        return await self.save_observation(
            observation_type='energy',
            title=title,
            description=description,
            severity=severity,
            value=level,
            conversation_id=conversation_id,
        )

    async def save_fall_observation(
        self,
        description: str,
        severity: str = 'moderate',
        injury_reported: bool = False,
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a fall observation"""
        title = "Fall reported"

        if injury_reported:
            severity = 'severe'
            title = "Fall with injury reported"

        return await self.save_observation(
            observation_type='fall',
            title=title,
            description=description,
            severity=severity,
            conversation_id=conversation_id,
            requires_attention=True,  # Falls always require attention
            concern_level=8 if injury_reported else 5,
        )

    async def save_general_observation(
        self,
        title: str,
        description: str,
        severity: str = 'normal',
        conversation_id: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Save a general observation"""
        return await self.save_observation(
            observation_type='general',
            title=title,
            description=description,
            severity=severity,
            conversation_id=conversation_id,
        )
