import aiohttp
from datetime import datetime

class MedicationApiService:
    def __init__(self, base_url: str, auth_token: str):
        self.base_url = base_url.rstrip('/')
        self.auth_token = auth_token
        self.headers = {
            'Authorization': f'Token {auth_token}',
            'Content-Type': 'application/json'
        }

    async def get_medications(self, active_only: bool = True):
        """Get user's medications"""
        try:
            url = f"{self.base_url}/medications/"
            params = {'active_only': str(active_only).lower()}

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=self.headers, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', [])
                    else:
                        print(f"❌ Failed to get medications: {response.status}")
                        return []
        except Exception as e:
            print(f"❌ Error getting medications: {e}")
            return []

    async def record_dose_taken(self, medication_id: str, scheduled_at: datetime,
                                 taken_at: datetime = None, notes: str = None,
                                 side_effect_note: str = None, is_late: bool = False):
        """Record that a dose was taken"""
        try:
            url = f"{self.base_url}/dose-events/"

            # Determine if dose was missed (not taken on time)
            # missed = True means it was late or not taken at all
            actual_taken = taken_at or datetime.now()
            was_late = is_late or (actual_taken > scheduled_at and (actual_taken - scheduled_at).total_seconds() > 1800)

            data = {
                'medication_id': medication_id,
                'scheduled_at': scheduled_at.isoformat(),
                'taken_at': actual_taken.isoformat(),
                'status': 'taken',
                'missed': was_late,  # True if not taken on time
                'method': 'voice'
            }
            if notes:
                data['notes'] = notes
            if side_effect_note:
                data['side_effect_note'] = side_effect_note

            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=self.headers, json=data) as response:
                    if response.status in [200, 201]:
                        result = await response.json()
                        print(f"✅ Dose recorded for medication {medication_id}")
                        return result.get('result')
                    else:
                        text = await response.text()
                        print(f"❌ Failed to record dose: {response.status} - {text}")
                        return None
        except Exception as e:
            print(f"❌ Error recording dose: {e}")
            return None

    async def record_dose_missed(self, medication_id: str, scheduled_at: datetime, reason: str = None):
        """Record that a dose was missed"""
        try:
            url = f"{self.base_url}/dose-events/"
            data = {
                'medication_id': medication_id,
                'scheduled_at': scheduled_at.isoformat(),
                'status': 'missed',
                'method': 'voice'
            }
            if reason:
                data['notes'] = reason

            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=self.headers, json=data) as response:
                    if response.status in [200, 201]:
                        result = await response.json()
                        print(f"⚠️ Missed dose recorded for medication {medication_id}")
                        return result.get('result')
                    else:
                        print(f"❌ Failed to record missed dose: {response.status}")
                        return None
        except Exception as e:
            print(f"❌ Error recording missed dose: {e}")
            return None

    async def record_side_effect(self, medication_id: str, severity: str,
                                  description: str, symptoms: list):
        """Record a side effect report"""
        try:
            url = f"{self.base_url}/side-effect-reports/"
            data = {
                'medication_id': medication_id,
                'severity': severity,  # 'mild', 'moderate', 'severe'
                'description': description,
                'symptoms': symptoms,
                'occurred_at': datetime.now().isoformat(),
                'reported_to_provider': False
            }

            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=self.headers, json=data) as response:
                    if response.status in [200, 201]:
                        result = await response.json()
                        print(f"📋 Side effect recorded for medication {medication_id}")
                        return result.get('result')
                    else:
                        text = await response.text()
                        print(f"❌ Failed to record side effect: {response.status} - {text}")
                        return None
        except Exception as e:
            print(f"❌ Error recording side effect: {e}")
            return None

    async def get_adherence_summary(self, period: str = 'sevenDays'):
        """Get adherence summary for the user"""
        try:
            url = f"{self.base_url}/adherence/summary/"
            params = {'period': period}

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=self.headers, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', {})
                    else:
                        print(f"❌ Failed to get adherence summary: {response.status}")
                        return {}
        except Exception as e:
            print(f"❌ Error getting adherence summary: {e}")
            return {}

    async def get_medication_history(self, period: str = 'week', medication_id: str = None):
        """
        Get detailed medication history with all dose events and analysis.

        Args:
            period: 'week', 'month', or 'all' (default: 'week')
            medication_id: Optional filter for specific medication

        Returns:
            Dict with summary, by_medication stats, problematic_medications, events, related_symptoms
        """
        try:
            url = f"{self.base_url}/medication-history/"
            params = {'period': period}
            if medication_id:
                params['medication_id'] = medication_id

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=self.headers, params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', {})
                    else:
                        print(f"❌ Failed to get medication history: {response.status}")
                        return {}
        except Exception as e:
            print(f"❌ Error getting medication history: {e}")
            return {}

    def format_medication_history_for_agent(self, history: dict) -> str:
        """Format medication history data for the agent to speak"""
        if not history:
            return "No medication history available."

        summary = history.get('summary', {})
        by_medication = history.get('by_medication', [])
        problematic = history.get('problematic_medications', [])
        symptoms = history.get('related_symptoms', [])
        period = history.get('period', 'week')

        lines = [f"Medication History for the past {period}:"]

        # Overall summary
        total = summary.get('total_events', 0)
        taken = summary.get('taken', 0)
        late = summary.get('late', 0)
        missed = summary.get('missed', 0)
        adherence = summary.get('overall_adherence', 100)

        if total > 0:
            lines.append(f"Overall adherence: {adherence:.0f} percent.")
            lines.append(f"Out of {total} scheduled doses: {taken} taken on time, {late} taken late, {missed} missed.")

        # Problematic medications
        if problematic:
            lines.append("")
            lines.append("Medications that need attention:")
            for med in problematic[:3]:  # Top 3
                name = med.get('medication_name', 'Unknown')
                med_missed = med.get('missed', 0)
                med_late = med.get('late', 0)
                avg_delay = med.get('avg_delay_minutes', 0)

                if med_missed > 0:
                    lines.append(f"- {name}: {med_missed} missed doses")
                if med_late > 0 and avg_delay > 0:
                    lines.append(f"- {name}: {med_late} late doses, average delay {avg_delay:.0f} minutes")

        # Related symptoms after missed/late doses
        if symptoms:
            symptom_after_missed = [s for s in symptoms if s.get('type') in ['symptom', 'side_effect']]
            if symptom_after_missed:
                lines.append("")
                lines.append("Related symptoms reported:")
                for s in symptom_after_missed[:3]:
                    lines.append(f"- {s.get('title', 'Unknown symptom')}: {s.get('severity', 'unknown')} severity")

        return "\n".join(lines)

    async def get_side_effect_reports(self, medication_id: str = None):
        """Get side effect reports"""
        try:
            if medication_id:
                url = f"{self.base_url}/medications/{medication_id}/side-effect-reports/"
            else:
                url = f"{self.base_url}/side-effect-reports/"

            async with aiohttp.ClientSession() as session:
                async with session.get(url, headers=self.headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get('result', [])
                    else:
                        print(f"❌ Failed to get side effect reports: {response.status}")
                        return []
        except Exception as e:
            print(f"❌ Error getting side effect reports: {e}")
            return []

    def format_medications_for_agent(self, medications: list) -> str:
        """Format medications list for the agent prompt - speech-friendly format"""
        if not medications:
            return "No active medications."

        formatted = []
        for med in medications:
            drug_name = med.get('drugName', 'Unknown')
            strength = med.get('strength', '')
            unit = med.get('strengthUnit', '')

            # Clean and format strength
            if strength:
                # Round decimal strengths
                try:
                    strength_val = float(strength)
                    if strength_val == int(strength_val):
                        strength = str(int(strength_val))
                    else:
                        strength = f"{strength_val:.1f}"
                except:
                    pass

            med_info = f"{drug_name} {strength} {unit}".strip()

            if med.get('form'):
                med_info += f", {med.get('form')}"
            if med.get('instructionsText'):
                instructions = med.get('instructionsText')
                # Remove any special characters from instructions
                instructions = instructions.replace('*', '').replace('#', '').strip()
                if instructions:
                    med_info += f". {instructions}"

            schedule = med.get('schedule', {})
            times = schedule.get('times', [])
            if times:
                # Convert times to speech-friendly format
                speech_times = []
                for t in times:
                    try:
                        # Parse time like "08:00" or "14:30"
                        parts = t.split(':')
                        hour = int(parts[0])
                        minute = int(parts[1]) if len(parts) > 1 else 0

                        # Convert to 12-hour format
                        period = "AM" if hour < 12 else "PM"
                        if hour == 0:
                            hour = 12
                        elif hour > 12:
                            hour = hour - 12

                        if minute == 0:
                            speech_times.append(f"{hour} {period}")
                        else:
                            speech_times.append(f"{hour}:{minute:02d} {period}")
                    except:
                        # If parsing fails, just use the original
                        speech_times.append(t.replace(':', ' '))

                med_info += f". Take at {', '.join(speech_times)}"

            formatted.append(med_info)

        return "Current Medications:\n" + "\n".join(formatted)

    def format_adherence_for_agent(self, adherence: dict) -> str:
        """Format adherence data for the agent"""
        if not adherence:
            return "No adherence data available."

        taken = adherence.get('taken_doses', 0)
        missed = adherence.get('missed_doses', 0)
        total = adherence.get('total_doses', 0)
        percentage = adherence.get('adherence_percentage', 0)

        return f"Adherence Summary (Last 7 days): {percentage:.0f}% ({taken}/{total} doses taken, {missed} missed)"


def get_medication_service(base_url: str, auth_token: str) -> MedicationApiService:
    """Factory function to get medication API service"""
    return MedicationApiService(base_url, auth_token)


class ObservationApiService:
    """Service for saving patient observations from conversations"""

    def __init__(self, base_url: str, auth_token: str):
        self.base_url = base_url.rstrip('/')
        self.auth_token = auth_token
        self.headers = {
            'Authorization': f'Token {auth_token}',
            'Content-Type': 'application/json'
        }

    async def save_observation(self, observation_type: str, title: str, description: str,
                                severity: str = 'normal', value: str = None,
                                medication_id: str = None, conversation_id: str = None,
                                requires_attention: bool = False, concern_level: int = 0):
        """Save a patient observation"""
        try:
            url = f"{self.base_url}/users/save_observation/"
            data = {
                'type': observation_type,
                'title': title,
                'description': description,
                'severity': severity,
                'requires_attention': requires_attention,
                'concern_level': concern_level,
                'source': 'voice'
            }
            if value:
                data['value'] = value
            if medication_id:
                data['medication_id'] = medication_id
            if conversation_id:
                data['conversation_id'] = conversation_id

            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=self.headers, json=data) as response:
                    if response.status in [200, 201]:
                        result = await response.json()
                        print(f"📝 Observation saved: {observation_type} - {title}")
                        return result.get('result')
                    else:
                        text = await response.text()
                        print(f"❌ Failed to save observation: {response.status} - {text}")
                        return None
        except Exception as e:
            print(f"❌ Error saving observation: {e}")
            return None

    async def save_medication_observation(self, medication_name: str, taken: bool,
                                           side_effect: str = None, conversation_id: str = None):
        """Save medication-related observation"""
        if taken:
            title = f"Took {medication_name}"
            description = f"Patient confirmed taking {medication_name}"
            severity = 'normal'
        else:
            title = f"Missed {medication_name}"
            description = f"Patient did not take {medication_name}"
            severity = 'mild'

        await self.save_observation(
            observation_type='medication',
            title=title,
            description=description,
            severity=severity,
            conversation_id=conversation_id
        )

        if side_effect:
            await self.save_observation(
                observation_type='side_effect',
                title=f"Side effect from {medication_name}",
                description=side_effect,
                severity='mild',
                requires_attention=True,
                conversation_id=conversation_id
            )

    async def save_sleep_observation(self, quality: str, hours: str = None,
                                      notes: str = None, conversation_id: str = None):
        """Save sleep observation"""
        severity = 'normal' if quality in ['good', 'excellent'] else 'mild'
        if quality in ['poor', 'terrible']:
            severity = 'moderate'

        await self.save_observation(
            observation_type='sleep',
            title=f"Sleep quality: {quality}",
            description=notes or f"Patient reported {quality} sleep",
            value=hours,
            severity=severity,
            requires_attention=quality in ['poor', 'terrible'],
            conversation_id=conversation_id
        )

    async def save_mood_observation(self, mood: str, notes: str = None, conversation_id: str = None):
        """Save mood observation"""
        severity = 'normal'
        requires_attention = False
        if mood in ['sad', 'anxious', 'stressed']:
            severity = 'mild'
        if mood in ['depressed', 'very_anxious', 'angry']:
            severity = 'moderate'
            requires_attention = True

        await self.save_observation(
            observation_type='mood',
            title=f"Mood: {mood}",
            description=notes or f"Patient feeling {mood}",
            severity=severity,
            requires_attention=requires_attention,
            conversation_id=conversation_id
        )

    async def save_symptom_observation(self, symptom: str, severity: str = 'mild',
                                        notes: str = None, conversation_id: str = None):
        """Save symptom observation"""
        await self.save_observation(
            observation_type='symptom',
            title=symptom,
            description=notes or f"Patient reported: {symptom}",
            severity=severity,
            requires_attention=severity in ['moderate', 'severe'],
            conversation_id=conversation_id
        )

    async def generate_report(self, report_type: str = 'daily'):
        """Trigger report generation"""
        try:
            url = f"{self.base_url}/users/generate_report/"
            data = {'report_type': report_type}

            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=self.headers, json=data) as response:
                    if response.status == 200:
                        result = await response.json()
                        print(f"📊 {report_type.capitalize()} report generated")
                        return result.get('result')
                    else:
                        print(f"❌ Failed to generate report: {response.status}")
                        return None
        except Exception as e:
            print(f"❌ Error generating report: {e}")
            return None


def get_observation_service(base_url: str, auth_token: str) -> ObservationApiService:
    """Factory function to get observation API service"""
    return ObservationApiService(base_url, auth_token)
