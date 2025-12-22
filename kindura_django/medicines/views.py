import logging
from django.shortcuts import render
from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import action
from .models import Medicine, MedicationEvent
from .serializers import MedicineSerializer, MedicationEventSerializer
from utils.response_utils import success_response, error_response
from utils.authentication import SimpleTokenAuthentication
from datetime import datetime, timedelta
from django.utils import timezone
from django.db.models import Count, Q

logger = logging.getLogger(__name__)


class MedicineViewSet(viewsets.ViewSet):
    """
    ViewSet for medicine management
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return Medicine.objects.filter(user=self.request.user, is_active=True)
    
    def list(self, request):
        """
        List all medicines for the authenticated user
        """
        try:
            medicines = self.get_queryset()
            serializer = MedicineSerializer(medicines, many=True)
            return success_response(serializer.data)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def create(self, request):
        """
        Create a new medicine
        """
        try:
            logger.info("MEDICATION CREATE REQUEST - User: %s, Data: %s", request.user.email, request.data)

            # Convert camelCase to snake_case for Flutter compatibility
            data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)

            # Remove fields that shouldn't be sent for creation
            fields_to_remove = ['id', 'createdAt', 'updatedAt', 'createdBy', 'pharmacy', 'rxNumber', 'refillsRemaining', 'notes']
            for field in fields_to_remove:
                data.pop(field, None)

            field_mapping = {
                'drugName': 'drug_name',
                'brandName': 'brand_name',
                'strengthUnit': 'strength_unit',
                'instructionsText': 'instructions_text',
                'takeWithFood': 'take_with_food',
                'asNeeded': 'as_needed',
                'missedDoseAction': 'missed_dose_action',
                'startDate': 'start_date',
                'endDate': 'end_date',
                'prescribedBy': 'prescriber',
                'profileId': 'profile_id',
                'isActive': 'is_active',
            }
            for camel, snake in field_mapping.items():
                if camel in data:
                    data[snake] = data.pop(camel)

            # Check for duplicate medication
            drug_name = data.get('drug_name', '').strip().lower()
            strength = data.get('strength', 0)
            strength_unit = data.get('strength_unit', '').strip().lower()
            form = data.get('form', '').strip().lower()

            existing = Medicine.objects.filter(
                user=request.user,
                is_active=True,
                drug_name__iexact=drug_name,
                strength=strength,
                strength_unit__iexact=strength_unit,
                form__iexact=form
            ).first()

            if existing:
                return error_response(
                    {'drug_name': [f'You already have {existing.drug_name} {existing.strength}{existing.strength_unit} ({existing.form}) in your medications']},
                    status.HTTP_400_BAD_REQUEST
                )

            serializer = MedicineSerializer(data=data)
            if serializer.is_valid():
                medicine = serializer.save(user=request.user)
                logger.info("Medication created: %s - %s", medicine.id, medicine.drug_name)
                return success_response(
                    MedicineSerializer(medicine).data,
                    "Medicine created successfully",
                    status.HTTP_201_CREATED
                )
            else:
                logger.warning("Validation errors: %s", serializer.errors)
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.exception("Exception in medication create: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def retrieve(self, request, pk=None):
        """
        Retrieve a specific medicine
        """
        try:
            medicine = self.get_queryset().get(pk=pk)
            serializer = MedicineSerializer(medicine)
            return success_response(serializer.data)
        except Medicine.DoesNotExist:
            return error_response("Medicine not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def update(self, request, pk=None):
        """
        Update a medicine
        """
        try:
            medicine = self.get_queryset().get(pk=pk)
            serializer = MedicineSerializer(medicine, data=request.data, partial=True)
            if serializer.is_valid():
                updated_medicine = serializer.save()
                return success_response(
                    MedicineSerializer(updated_medicine).data,
                    "Medicine updated successfully"
                )
            else:
                return error_response(serializer.errors, status.HTTP_400_BAD_REQUEST)
        except Medicine.DoesNotExist:
            return error_response("Medicine not found", status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def destroy(self, request, pk=None):
        """
        Soft delete a medicine (set is_active to False)
        """
        try:
            # Find any medication for this user (active or not)
            medicine = Medicine.objects.filter(user=request.user, pk=pk).first()
            if not medicine:
                return error_response("Medicine not found", status.HTTP_404_NOT_FOUND)

            medicine.is_active = False
            medicine.save()
            return success_response(message="Medicine deleted successfully")
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'])
    def deactivate(self, request, pk=None):
        """
        Deactivate/soft delete a medicine (Flutter app endpoint)
        """
        try:
            medicine = Medicine.objects.filter(user=request.user, pk=pk).first()
            if not medicine:
                return error_response("Medicine not found", status.HTTP_404_NOT_FOUND)

            medicine.is_active = False
            medicine.save()
            return success_response(message="Medicine deactivated successfully")
        except Exception as e:
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class DoseEventViewSet(viewsets.ViewSet):
    """
    ViewSet for dose event management
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def create(self, request):
        """
        Record a dose event (taken, missed, skipped)
        """
        try:
            data = request.data
            medication_id = data.get('medication_id')
            scheduled_at = data.get('scheduled_at')
            taken_at = data.get('taken_at')
            event_status = data.get('status', 'taken')
            method = data.get('method', 'app')
            notes = data.get('notes')
            side_effect_note = data.get('side_effect_note')

            # Validate medication belongs to user
            try:
                medication = Medicine.objects.get(id=medication_id, user=request.user)
            except Medicine.DoesNotExist:
                return error_response("Medication not found", status.HTTP_404_NOT_FOUND)

            # Parse dates
            if isinstance(scheduled_at, str):
                scheduled_at = datetime.fromisoformat(scheduled_at.replace('Z', '+00:00'))
            if isinstance(taken_at, str):
                taken_at = datetime.fromisoformat(taken_at.replace('Z', '+00:00'))

            # Calculate delay if taken
            delay_minutes = None
            if event_status == 'taken' and taken_at and scheduled_at:
                delay = taken_at - scheduled_at
                delay_minutes = int(delay.total_seconds() / 60)

                # Automatically determine status based on delay
                # If more than 30 minutes late, mark as 'late'
                # This can be adjusted based on requirements
                if abs(delay_minutes) > 30:
                    event_status = 'late'
                    logger.info("Medication taken %d minutes late - marking as 'late'", abs(delay_minutes))

            # Create dose event
            dose_event = MedicationEvent.objects.create(
                medication=medication,
                scheduled_at=scheduled_at,
                taken_at=taken_at if event_status in ['taken', 'late'] else None,
                status=event_status,
                delay_minutes=delay_minutes,
                side_effect_note=side_effect_note,
                source=method
            )

            logger.info("Dose event recorded: %s - %s", medication.drug_name, event_status)

            # Toon format: y=type, id=id, mid=medication_id, st=status, sa=scheduled_at, ta=taken_at, dm=delay_minutes
            return success_response({
                'y': 'ev',
                'id': dose_event.id,
                'mid': medication_id,
                'st': event_status,
                'sa': scheduled_at.isoformat() if scheduled_at else None,
                'ta': taken_at.isoformat() if taken_at else None,
                'dm': delay_minutes,
                # Also include readable keys for Flutter compatibility
                'medication_id': medication_id,
                'status': event_status,
                'scheduled_at': scheduled_at.isoformat() if scheduled_at else None,
                'taken_at': taken_at.isoformat() if taken_at else None,
                'delay_minutes': delay_minutes,
            }, "Dose event recorded successfully", status.HTTP_201_CREATED)

        except Exception as e:
            logger.error("Error recording dose event: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdherenceSummaryView(viewsets.ViewSet):
    """
    ViewSet for adherence summary
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        Get adherence summary for the user
        """
        try:
            period = request.query_params.get('period', 'sevenDays')

            # Calculate date range
            now = timezone.now()
            if period == 'sevenDays':
                start_date = now - timedelta(days=7)
            elif period == 'thirtyDays':
                start_date = now - timedelta(days=30)
            else:
                start_date = now - timedelta(days=7)

            # Get dose events for the period (only from active medications)
            events = MedicationEvent.objects.filter(
                medication__user=request.user,
                medication__is_active=True,
                scheduled_at__gte=start_date,
                scheduled_at__lte=now
            )

            total = events.count()
            taken = events.filter(status='taken').count()
            missed = events.filter(status='missed').count()
            late = events.filter(status='late').count()

            # Calculate today's stats
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            today_events = events.filter(scheduled_at__gte=today_start)
            today_taken = today_events.filter(status='taken').count()
            today_scheduled = today_events.filter(status='scheduled').count()
            today_missed = today_events.filter(status='missed').count()

            # Calculate total daily doses from all active medications
            # Each medication can have multiple scheduled times per day
            active_meds = Medicine.objects.filter(user=request.user, is_active=True)
            total_daily_doses = 0
            for med in active_meds:
                schedule = med.schedule or {}
                times = schedule.get('times', [])
                # Count number of scheduled times per day
                total_daily_doses += len(times) if times else 1  # Default to 1 if no times specified

            # Pending = total daily doses minus what's already been handled (taken or missed)
            # This correctly decreases as each dose is marked as taken
            today_pending = max(0, total_daily_doses - today_taken - today_missed)

            adherence_percentage = (taken / total * 100) if total > 0 else 100

            # Toon format for AI processing efficiency
            # p=period, ap=adherence_percentage, td=total_doses
            # tk=taken, ms=missed, lt=late
            # tTk=todayTaken, tPd=todayPending, tMs=todayMissed
            return success_response({
                'p': period,
                'ap': round(adherence_percentage, 1),
                'td': total,
                'tk': taken,
                'ms': missed,
                'lt': late,
                'tTk': today_taken,
                'tPd': today_pending,
                'tMs': today_missed,
                # Also include readable keys for Flutter compatibility
                'period': period,
                'adherence_percentage': round(adherence_percentage, 1),
                'total_doses': total,
                'taken_doses': taken,
                'missed_doses': missed,
                'late_doses': late,
                'todayTaken': today_taken,
                'todayPending': today_pending,
                'todayMissed': today_missed,
            })

        except Exception as e:
            logger.error("Error getting adherence summary: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class MedicationHistoryView(viewsets.ViewSet):
    """
    ViewSet for detailed medication history and adherence analysis
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        Get detailed medication history with all dose events and analysis

        Query params:
        - period: 'week', 'month', 'all' (default: 'week')
        - medication_id: Filter by specific medication (optional)
        """
        try:
            period = request.query_params.get('period', 'week')
            medication_id = request.query_params.get('medication_id')

            # Calculate date range
            now = timezone.now()
            if period == 'week':
                start_date = now - timedelta(days=7)
            elif period == 'month':
                start_date = now - timedelta(days=30)
            elif period == 'all':
                start_date = now - timedelta(days=365)  # Max 1 year
            else:
                start_date = now - timedelta(days=7)

            # Base query for events
            events_query = MedicationEvent.objects.filter(
                medication__user=request.user,
                medication__is_active=True,
                scheduled_at__gte=start_date,
                scheduled_at__lte=now
            ).select_related('medication')

            if medication_id:
                events_query = events_query.filter(medication_id=medication_id)

            events = events_query.order_by('-scheduled_at')

            # Prepare detailed event list
            events_list = []
            for event in events:
                event_data = {
                    'id': event.id,
                    'medication_id': event.medication.id,
                    'medication_name': event.medication.drug_name,
                    'strength': f"{event.medication.strength} {event.medication.strength_unit}" if event.medication.strength else '',
                    'scheduled_at': event.scheduled_at.isoformat(),
                    'taken_at': event.taken_at.isoformat() if event.taken_at else None,
                    'status': event.status,
                    'delay_minutes': event.delay_minutes,
                    'side_effect_note': event.side_effect_note,
                    'source': event.source,
                }
                events_list.append(event_data)

            # Calculate per-medication stats
            medication_stats = {}
            for event in events:
                med_id = event.medication.id
                if med_id not in medication_stats:
                    medication_stats[med_id] = {
                        'medication_id': med_id,
                        'medication_name': event.medication.drug_name,
                        'total': 0,
                        'taken': 0,
                        'late': 0,
                        'missed': 0,
                        'skipped': 0,
                        'avg_delay_minutes': 0,
                        'delay_events': [],
                    }

                stats = medication_stats[med_id]
                stats['total'] += 1

                if event.status == 'taken':
                    stats['taken'] += 1
                elif event.status == 'late':
                    stats['late'] += 1
                    if event.delay_minutes:
                        stats['delay_events'].append(event.delay_minutes)
                elif event.status == 'missed':
                    stats['missed'] += 1
                elif event.status == 'skipped':
                    stats['skipped'] += 1

            # Calculate average delays
            for med_id, stats in medication_stats.items():
                if stats['delay_events']:
                    stats['avg_delay_minutes'] = round(sum(stats['delay_events']) / len(stats['delay_events']), 1)
                del stats['delay_events']  # Remove temp array

                # Calculate adherence percentage
                if stats['total'] > 0:
                    stats['adherence_percentage'] = round((stats['taken'] + stats['late']) / stats['total'] * 100, 1)
                else:
                    stats['adherence_percentage'] = 100.0

            # Overall analysis
            total_events = len(events_list)
            taken_count = sum(1 for e in events_list if e['status'] == 'taken')
            late_count = sum(1 for e in events_list if e['status'] == 'late')
            missed_count = sum(1 for e in events_list if e['status'] == 'missed')
            skipped_count = sum(1 for e in events_list if e['status'] == 'skipped')

            # Find problematic patterns
            problematic_meds = [
                stats for stats in medication_stats.values()
                if stats['missed'] > 0 or stats['late'] > 2
            ]

            # Get related symptoms from observations if available
            try:
                from users.models import PatientObservation
                symptoms = PatientObservation.objects.filter(
                    user=request.user,
                    type__in=['symptom', 'side_effect'],
                    created_at__gte=start_date,
                    created_at__lte=now
                ).order_by('-created_at')[:20]

                symptom_list = [{
                    'id': s.id,
                    'type': s.type,
                    'title': s.title,
                    'description': s.description,
                    'severity': s.severity,
                    'reported_at': s.created_at.isoformat(),
                    'medication_id': s.medication_id,
                } for s in symptoms]
            except:
                symptom_list = []

            return success_response({
                'period': period,
                'start_date': start_date.isoformat(),
                'end_date': now.isoformat(),
                'summary': {
                    'total_events': total_events,
                    'taken': taken_count,
                    'late': late_count,
                    'missed': missed_count,
                    'skipped': skipped_count,
                    'overall_adherence': round((taken_count + late_count) / total_events * 100, 1) if total_events > 0 else 100.0,
                },
                'by_medication': list(medication_stats.values()),
                'problematic_medications': problematic_meds,
                'events': events_list[:100],  # Limit to 100 most recent
                'related_symptoms': symptom_list,
            })

        except Exception as e:
            logger.error("Error getting medication history: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class SideEffectViewSet(viewsets.ViewSet):
    """
    ViewSet for side effect reports
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def create(self, request):
        """
        Record a side effect report
        """
        try:
            data = request.data
            medication_id = data.get('medication_id')
            severity = data.get('severity', 'mild')
            description = data.get('description', '')
            symptoms = data.get('symptoms', [])
            occurred_at = data.get('occurred_at')
            notes = data.get('notes')

            # Validate medication belongs to user
            try:
                medication = Medicine.objects.get(id=medication_id, user=request.user)
            except Medicine.DoesNotExist:
                return error_response("Medication not found", status.HTTP_404_NOT_FOUND)

            # Parse date
            if isinstance(occurred_at, str):
                occurred_at = datetime.fromisoformat(occurred_at.replace('Z', '+00:00'))
            else:
                occurred_at = timezone.now()

            # Store as a dose event with side effect note
            side_effect_entry = MedicationEvent.objects.create(
                medication=medication,
                scheduled_at=occurred_at,
                status='taken',
                side_effect_note=f"[{severity.upper()}] {description}. Symptoms: {', '.join(symptoms)}. {notes or ''}",
                source='voice'
            )

            logger.info("Side effect recorded: %s - %s - %s", medication.drug_name, severity, description)

            # Toon format: y=type, sv=severity, d=description, sym=symptoms, oa=occurred_at
            return success_response({
                'y': 'se',  # side effect
                'id': side_effect_entry.id,
                'mid': medication_id,
                'sv': severity,
                'd': description,
                'sym': symptoms,
                'oa': occurred_at.isoformat(),
                'rp': False,  # reported_to_provider
                # Readable keys for Flutter
                'medication_id': medication_id,
                'severity': severity,
                'description': description,
                'symptoms': symptoms,
                'occurred_at': occurred_at.isoformat(),
                'reported_to_provider': False,
            }, "Side effect recorded successfully", status.HTTP_201_CREATED)

        except Exception as e:
            logger.error("Error recording side effect: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

    def list(self, request):
        """
        Get side effect reports
        """
        try:
            # Get events with side effect notes
            events = MedicationEvent.objects.filter(
                medication__user=request.user,
                side_effect_note__isnull=False
            ).exclude(side_effect_note='').order_by('-created_at')[:50]

            reports = []
            for event in events:
                reports.append({
                    'id': event.id,
                    'medication_id': event.medication.id,
                    'medication_name': event.medication.drug_name,
                    'description': event.side_effect_note,
                    'occurred_at': event.scheduled_at.isoformat(),
                    'created_at': event.created_at.isoformat(),
                })

            return success_response(reports)

        except Exception as e:
            logger.error("Error getting side effect reports: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


class AIAdherenceAnalysisView(viewsets.ViewSet):
    """
    ViewSet for AI-powered medication adherence analysis
    Uses OpenAI to analyze medication adherence along with vitals, labs, and symptoms
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        Get AI-powered adherence analysis for the user
        Query params: period (day, week, month)
        """
        try:
            period = request.query_params.get('period', 'week')

            # Get cached analysis if available
            cached_analysis = self._get_cached_analysis(request.user, period)
            if cached_analysis:
                return success_response(cached_analysis)

            # Generate new analysis
            analysis = self._generate_analysis(request.user, period)
            return success_response(analysis)

        except Exception as e:
            logger.error("Error getting AI analysis: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

    def create(self, request):
        """
        Request a new AI analysis (force regeneration)
        """
        try:
            period = request.data.get('period', 'week')
            include_vitals = request.data.get('include_vitals', True)
            include_labs = request.data.get('include_labs', True)
            include_symptoms = request.data.get('include_symptoms', True)

            analysis = self._generate_analysis(
                request.user, period,
                include_vitals=include_vitals,
                include_labs=include_labs,
                include_symptoms=include_symptoms,
                force_regenerate=True
            )

            return success_response(analysis, "Analysis generated successfully")

        except Exception as e:
            logger.error("Error generating AI analysis: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)

    def _get_cached_analysis(self, user, period):
        """Check for recent cached analysis"""
        # For now, return None to always generate fresh analysis
        # Can implement caching with PatientReport model later
        return None

    def _generate_analysis(self, user, period, include_vitals=True, include_labs=True,
                          include_symptoms=True, force_regenerate=False):
        """Generate AI-powered adherence analysis"""
        import json
        from llm_model.gpt_model import GPTModel

        # Calculate date range
        now = timezone.now()
        if period == 'day':
            start_date = now - timedelta(days=1)
        elif period == 'week':
            start_date = now - timedelta(days=7)
        elif period == 'month':
            start_date = now - timedelta(days=30)
        else:
            start_date = now - timedelta(days=7)

        # Gather medication history data
        med_data = self._get_medication_data(user, start_date, now)

        # Gather vitals data if requested
        vitals_data = {}
        if include_vitals:
            vitals_data = self._get_vitals_data(user, start_date, now)

        # Gather labs data if requested
        labs_data = {}
        if include_labs:
            labs_data = self._get_labs_data(user, start_date, now)

        # Gather symptoms/observations if requested
        symptoms_data = []
        if include_symptoms:
            symptoms_data = self._get_symptoms_data(user, start_date, now)

        # Build prompt for OpenAI
        prompt = self._build_analysis_prompt(med_data, vitals_data, labs_data, symptoms_data, period)

        # Call OpenAI
        try:
            gpt = GPTModel(model="gpt-4o-mini")
            messages = [
                {"role": "system", "content": self._get_system_prompt()},
                {"role": "user", "content": prompt}
            ]

            response = gpt.chat(messages, temperature=0.3, max_tokens=4000)

            if response:
                analysis = json.loads(response)
                # Add metadata
                analysis['analysisId'] = f"ai_{user.id}_{now.strftime('%Y%m%d%H%M%S')}"
                analysis['analysisDate'] = now.isoformat()
                analysis['period'] = period
                analysis['confidenceScore'] = analysis.get('confidenceScore', 0.85)
                return analysis
            else:
                return self._get_fallback_analysis(med_data, period, now)

        except Exception as e:
            logger.error("OpenAI analysis failed: %s", e)
            return self._get_fallback_analysis(med_data, period, now)

    def _get_system_prompt(self):
        return """You are a PhD-level medical doctor specializing in Parkinson's disease and movement disorders.
You are analyzing medication adherence data for a patient who may have Parkinson's disease or other conditions.

Your task is to provide a comprehensive medical analysis of the patient's medication adherence patterns,
correlating them with any available vitals, lab results, and reported symptoms.

IMPORTANT: Provide clinically relevant insights that would help:
1. The patient understand their medication patterns
2. Caregivers monitor the patient effectively
3. The treating physician make informed decisions

Consider Parkinson's-specific factors:
- On/off fluctuations and their timing relative to medication
- The importance of precise timing for levodopa medications
- How missed or late doses affect motor symptoms
- The relationship between sleep quality and medication timing
- Potential drug interactions common in PD treatment

Respond ONLY with a valid JSON object in this exact format:
{
  "overallAssessment": "A 2-3 sentence summary of the overall adherence status and key findings",
  "sections": [
    {
      "title": "Section title",
      "content": "Detailed analysis content",
      "severity": "info|warning|critical",
      "bulletPoints": ["Point 1", "Point 2"]
    }
  ],
  "recommendations": ["Recommendation 1", "Recommendation 2", "Recommendation 3"],
  "warnings": ["Any urgent warnings if applicable"],
  "parkinsonsSpecificNotes": "Parkinson's-specific observations if the patient appears to be on PD medications",
  "confidenceScore": 0.85
}"""

    def _get_medication_data(self, user, start_date, end_date):
        """Get medication adherence data"""
        events = MedicationEvent.objects.filter(
            medication__user=user,
            medication__is_active=True,
            scheduled_at__gte=start_date,
            scheduled_at__lte=end_date
        ).select_related('medication')

        meds = Medicine.objects.filter(user=user, is_active=True)

        med_summary = {}
        for med in meds:
            med_events = events.filter(medication=med)
            total = med_events.count()
            taken = med_events.filter(status='taken').count()
            late = med_events.filter(status='late').count()
            missed = med_events.filter(status='missed').count()

            med_summary[med.drug_name] = {
                'strength': f"{med.strength} {med.strength_unit}",
                'form': med.form,
                'schedule': med.schedule if hasattr(med, 'schedule') else [],
                'total_doses': total,
                'taken': taken,
                'late': late,
                'missed': missed,
                'adherence_pct': round((taken + late) / total * 100, 1) if total > 0 else 100
            }

        return {
            'medications': med_summary,
            'total_events': events.count(),
            'overall_taken': events.filter(status='taken').count(),
            'overall_late': events.filter(status='late').count(),
            'overall_missed': events.filter(status='missed').count()
        }

    def _get_vitals_data(self, user, start_date, end_date):
        """Get vitals data from Apple Watch or other sources"""
        try:
            from health_profile.models import WatchVitals
            vitals = WatchVitals.objects.filter(
                user=user,
                recorded_at__gte=start_date,
                recorded_at__lte=end_date
            ).order_by('-recorded_at')[:50]

            if not vitals:
                return {}

            # Calculate averages
            heart_rates = [v.heart_rate for v in vitals if v.heart_rate]
            blood_oxygen = [v.blood_oxygen for v in vitals if v.blood_oxygen]
            sleep_hours = [v.sleep_hours for v in vitals if v.sleep_hours]

            return {
                'avg_heart_rate': round(sum(heart_rates) / len(heart_rates), 1) if heart_rates else None,
                'avg_blood_oxygen': round(sum(blood_oxygen) / len(blood_oxygen), 1) if blood_oxygen else None,
                'avg_sleep_hours': round(sum(sleep_hours) / len(sleep_hours), 1) if sleep_hours else None,
                'readings_count': len(vitals)
            }
        except Exception as e:
            logger.error("Error getting vitals: %s", e)
            return {}

    def _get_labs_data(self, user, start_date, end_date):
        """Get biomarker/lab data"""
        try:
            from medical_reports.models import UserBiomarker
            biomarkers = UserBiomarker.objects.filter(
                user=user,
                observation_date__gte=start_date.date()
            ).order_by('-observation_date')[:20]

            if not biomarkers:
                return {}

            abnormal = biomarkers.filter(status__in=['high', 'low', 'critical_high', 'critical_low'])

            return {
                'total_biomarkers': biomarkers.count(),
                'abnormal_count': abnormal.count(),
                'recent_abnormal': [
                    {'name': b.name, 'value': b.value, 'unit': b.unit, 'status': b.status}
                    for b in abnormal[:5]
                ]
            }
        except Exception as e:
            logger.error("Error getting labs: %s", e)
            return {}

    def _get_symptoms_data(self, user, start_date, end_date):
        """Get symptom observations"""
        try:
            from users.models import PatientObservation
            observations = PatientObservation.objects.filter(
                user=user,
                created_at__gte=start_date,
                created_at__lte=end_date,
                type__in=['symptom', 'side_effect', 'mood', 'sleep', 'energy']
            ).order_by('-created_at')[:30]

            return [
                {
                    'type': o.type,
                    'title': o.title,
                    'severity': o.severity,
                    'date': o.created_at.isoformat()
                }
                for o in observations
            ]
        except Exception as e:
            logger.error("Error getting symptoms: %s", e)
            return []

    def _build_analysis_prompt(self, med_data, vitals_data, labs_data, symptoms_data, period):
        """Build the analysis prompt for OpenAI"""
        import json
        prompt = f"""Analyze the following patient data for the past {period}:

## Medication Adherence Data:
{json.dumps(med_data, indent=2) if med_data else 'No medication data available'}

## Vitals Data (from Apple Watch):
{json.dumps(vitals_data, indent=2) if vitals_data else 'No vitals data available'}

## Lab Results:
{json.dumps(labs_data, indent=2) if labs_data else 'No lab data available'}

## Reported Symptoms and Observations:
{json.dumps(symptoms_data, indent=2) if symptoms_data else 'No symptom data available'}

Please provide a comprehensive analysis considering:
1. Overall medication adherence assessment
2. Patterns in missed or late doses (time of day, specific medications)
3. Correlation between adherence issues and any reported symptoms
4. Impact on vitals if data is available
5. Lab result implications
6. Parkinson's-specific considerations if applicable (look for levodopa, carbidopa, dopamine agonists)
7. Actionable recommendations for improving adherence
8. Any warnings that require attention"""

        return prompt

    def _get_fallback_analysis(self, med_data, period, now):
        """Generate a basic analysis when OpenAI fails"""
        total = med_data.get('total_events', 0)
        taken = med_data.get('overall_taken', 0)
        late = med_data.get('overall_late', 0)
        missed = med_data.get('overall_missed', 0)

        adherence_pct = round((taken + late) / total * 100, 1) if total > 0 else 100

        sections = []
        recommendations = []
        warnings = []

        if adherence_pct >= 90:
            assessment = f"Excellent medication adherence ({adherence_pct}%) over the past {period}. Keep up the great work!"
            sections.append({
                'title': 'Adherence Status',
                'content': f'You have taken {taken + late} out of {total} scheduled doses, with an adherence rate of {adherence_pct}%.',
                'severity': 'info',
                'bulletPoints': ['Adherence is within optimal range', 'Continue current routine']
            })
        elif adherence_pct >= 70:
            assessment = f"Good medication adherence ({adherence_pct}%) with room for improvement. {missed} doses were missed."
            sections.append({
                'title': 'Adherence Status',
                'content': f'You have taken {taken + late} out of {total} scheduled doses. {missed} doses were missed.',
                'severity': 'warning',
                'bulletPoints': [f'{missed} doses missed', f'{late} doses taken late']
            })
            recommendations.append('Set up medication reminders on your phone')
            recommendations.append('Consider using a pill organizer')
        else:
            assessment = f"Medication adherence needs attention ({adherence_pct}%). {missed} doses missed which may affect treatment effectiveness."
            sections.append({
                'title': 'Adherence Status',
                'content': f'Only {taken + late} out of {total} scheduled doses were taken. This may impact treatment effectiveness.',
                'severity': 'critical',
                'bulletPoints': [f'{missed} doses missed', 'Discuss with your healthcare provider']
            })
            warnings.append('Low adherence may affect treatment outcomes - please discuss with your doctor')
            recommendations.append('Schedule a review with your healthcare provider')
            recommendations.append('Consider medication reminder apps or caregiver assistance')

        return {
            'analysisId': f"fallback_{now.strftime('%Y%m%d%H%M%S')}",
            'analysisDate': now.isoformat(),
            'period': period,
            'overallAssessment': assessment,
            'sections': sections,
            'recommendations': recommendations,
            'warnings': warnings,
            'parkinsonsSpecificNotes': None,
            'confidenceScore': 0.6
        }


class MedicationScheduleChangesView(viewsets.ViewSet):
    """
    ViewSet for tracking medication schedule changes over time
    """
    authentication_classes = [SimpleTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        """
        Get medication schedule changes for the user
        Query params: period (day, week, month), medication_id (optional)
        """
        try:
            period = request.query_params.get('period', 'month')
            medication_id = request.query_params.get('medication_id')

            # Calculate date range
            now = timezone.now()
            if period == 'day':
                start_date = now - timedelta(days=1)
            elif period == 'week':
                start_date = now - timedelta(days=7)
            elif period == 'month':
                start_date = now - timedelta(days=30)
            else:
                start_date = now - timedelta(days=30)

            # Get medications
            medications = Medicine.objects.filter(user=request.user)
            if medication_id:
                medications = medications.filter(id=medication_id)

            # Build schedule changes list
            # This tracks changes like dose time changes, frequency changes, etc.
            changes = []

            for med in medications:
                # Check if medication was created in this period
                if med.created_at and med.created_at >= start_date:
                    changes.append({
                        'id': f"change_{med.id}_created",
                        'medicationId': str(med.id),
                        'medicationName': med.drug_name,
                        'changeType': 'medication_added',
                        'description': f'{med.drug_name} was added to your medications',
                        'previousValue': None,
                        'newValue': f'{med.strength} {med.strength_unit}',
                        'changedAt': med.created_at.isoformat(),
                        'changedBy': 'user'
                    })

                # Check if medication was deactivated
                if not med.is_active:
                    changes.append({
                        'id': f"change_{med.id}_deactivated",
                        'medicationId': str(med.id),
                        'medicationName': med.drug_name,
                        'changeType': 'medication_deactivated',
                        'description': f'{med.drug_name} was deactivated',
                        'previousValue': 'active',
                        'newValue': 'inactive',
                        'changedAt': med.updated_at.isoformat() if med.updated_at else now.isoformat(),
                        'changedBy': 'user'
                    })

            # Sort by date, most recent first
            changes.sort(key=lambda x: x['changedAt'], reverse=True)

            return success_response(changes)

        except Exception as e:
            logger.error("Error getting schedule changes: %s", e)
            return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)
