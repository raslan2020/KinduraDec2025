"""
Enhanced Kindura Report Service
Generates comprehensive daily/weekly/monthly reports with detailed analytics
"""
import logging
import json
import os
from datetime import date, datetime, timedelta
from django.db.models import Avg, Sum, Count, Min, Max
from django.db.models.functions import TruncDate
from django.utils import timezone
import openai

logger = logging.getLogger(__name__)


class ReportService:
    """
    Service class for generating enhanced Kindura patient reports
    """

    def __init__(self, user, report_instance=None):
        self.user = user
        self.report_instance = report_instance  # For progress tracking
        openai.api_key = os.getenv('OPENAI_API_KEY')

    def _update_progress(self, progress, save=True):
        """Update report progress in database"""
        if self.report_instance:
            self.report_instance.progress = progress
            if save:
                self.report_instance.save(update_fields=['progress', 'updated_at'])
            logger.info(f"Report {self.report_instance.id} progress: {progress}%")

    def generate_comprehensive_report(self, report_type='daily'):
        """
        Generate a comprehensive report with ALL available data sources
        Progress stages:
        - 5%: Started, determining date range
        - 10%: Collecting observations
        - 15%: Collecting medication data
        - 25%: Collecting vitals data (including extended vitals)
        - 35%: Collecting activity data (steps, calories, exercise)
        - 40%: Collecting mobility data (walking metrics, gait)
        - 45%: Collecting sleep data
        - 50%: Collecting fall data
        - 55%: Collecting biomarker data
        - 60%: Collecting clinical data (motor, non-motor, speech, cognitive)
        - 65%: Collecting conversation data
        - 70%: Collecting medical reports
        - 75%: Analyzing trends and patterns
        - 85%: Calculating health scores
        - 90%: Running AI analysis
        - 100%: Complete
        """
        self._update_progress(5)

        # Determine date range
        today = date.today()
        if report_type == 'daily':
            period_start = today
            period_end = today
        elif report_type == 'weekly':
            period_start = today - timedelta(days=today.weekday())
            period_end = period_start + timedelta(days=6)
        else:  # monthly
            period_start = today.replace(day=1)
            next_month = today.replace(day=28) + timedelta(days=4)
            period_end = next_month - timedelta(days=next_month.day)

        # Collect all data
        report_data = {
            'report_type': report_type,
            'period_start': period_start,
            'period_end': period_end,
            'generated_at': timezone.now(),
        }

        # Collect each type of data with progress updates
        self._update_progress(10)
        report_data['observations'] = self._collect_observations(period_start, period_end)

        self._update_progress(15)
        report_data['medication_data'] = self._collect_medication_data(period_start, period_end)

        self._update_progress(25)
        report_data['vitals_data'] = self._collect_vitals_data(period_start, period_end)

        # NEW: Collect activity data (steps, calories, exercise, etc.)
        self._update_progress(35)
        report_data['activity_data'] = self._collect_activity_data(period_start, period_end)

        # NEW: Collect mobility metrics (walking asymmetry, speed, gait balance)
        self._update_progress(40)
        report_data['mobility_data'] = self._collect_mobility_data(period_start, period_end)

        self._update_progress(45)
        report_data['sleep_data'] = self._collect_sleep_data(period_start, period_end)

        self._update_progress(50)
        report_data['fall_data'] = self._collect_fall_data(period_start, period_end)

        self._update_progress(55)
        report_data['biomarker_data'] = self._collect_biomarker_data(period_start, period_end)

        # Clinical data (motor/non-motor symptoms, safety events, speech, cognitive)
        self._update_progress(60)
        report_data['clinical_data'] = self._collect_clinical_data(period_start, period_end)

        # Conversation history from agent
        self._update_progress(65)
        report_data['conversation_data'] = self._collect_conversation_data(period_start, period_end)

        # Medical reports
        self._update_progress(70)
        report_data['medical_reports'] = self._collect_medical_reports(period_start, period_end)

        # Analyze trends and patterns
        self._update_progress(75)
        report_data['trends'] = self._analyze_trends(report_data, period_start, period_end)

        # Calculate health scores (including clinical score)
        self._update_progress(85)
        report_data['scores'] = self._calculate_health_scores(report_data)

        # Generate AI analysis with ALL data sources
        self._update_progress(90)
        report_data['ai_analysis'] = self._generate_ai_analysis(report_data, report_type)

        self._update_progress(100, save=False)  # Will be saved with final report data
        return report_data

    def _collect_observations(self, period_start, period_end):
        """Collect patient observations for the period"""
        from .models import PatientObservation

        observations = PatientObservation.objects.filter(
            user=self.user,
            observed_at__date__gte=period_start,
            observed_at__date__lte=period_end
        ).order_by('observed_at')

        obs_by_type = {}
        for obs in observations:
            if obs.observation_type not in obs_by_type:
                obs_by_type[obs.observation_type] = []
            obs_by_type[obs.observation_type].append({
                'date': obs.observed_at.strftime('%Y-%m-%d'),
                'time': obs.observed_at.strftime('%H:%M'),
                'title': obs.title,
                'description': obs.description,
                'value': obs.value,
                'severity': obs.severity,
                'requires_attention': obs.requires_attention,
            })

        return {
            'total_count': observations.count(),
            'by_type': obs_by_type,
            'attention_required': observations.filter(requires_attention=True).count(),
            'severe_count': observations.filter(severity__in=['severe', 'critical']).count(),
        }

    def _collect_medication_data(self, period_start, period_end):
        """Collect medication adherence and side effect data"""
        from medicines.models import Medicine, MedicationEvent

        medications = Medicine.objects.filter(user=self.user, is_active=True)
        med_events = MedicationEvent.objects.filter(
            medication__user=self.user,
            scheduled_at__date__gte=period_start,
            scheduled_at__date__lte=period_end
        )

        # Overall stats
        total_doses = med_events.count()
        taken_doses = med_events.filter(status='taken').count()
        missed_doses = med_events.filter(status='missed').count()
        late_doses = med_events.filter(status='late').count()
        adherence_pct = (taken_doses / total_doses * 100) if total_doses > 0 else 100

        # Per-medication analytics
        med_analytics = {}
        for med in medications:
            med_events_for_med = med_events.filter(medication=med)
            total = med_events_for_med.count()
            taken = med_events_for_med.filter(status='taken').count()
            missed = med_events_for_med.filter(status='missed').count()
            late = med_events_for_med.filter(status='late').count()

            # Get side effects for this medication
            side_effects = []
            for event in med_events_for_med:
                if event.side_effect_note:
                    side_effects.append({
                        'date': event.scheduled_at.strftime('%Y-%m-%d'),
                        'note': event.side_effect_note,
                    })

            med_analytics[str(med.id)] = {
                'drug_name': med.drug_name,
                'strength': f"{med.strength}{med.strength_unit}",
                'total_doses': total,
                'taken': taken,
                'missed': missed,
                'late': late,
                'adherence_pct': (taken / total * 100) if total > 0 else 100,
                'side_effects': side_effects,
                'timing_accuracy': self._calculate_timing_accuracy(med_events_for_med),
            }

        # Daily adherence trend (for graph)
        daily_adherence = []
        current_date = period_start
        while current_date <= period_end:
            day_events = med_events.filter(scheduled_at__date=current_date)
            day_total = day_events.count()
            day_taken = day_events.filter(status='taken').count()
            daily_adherence.append({
                'date': current_date.strftime('%Y-%m-%d'),
                'total': day_total,
                'taken': day_taken,
                'adherence_pct': (day_taken / day_total * 100) if day_total > 0 else 100,
            })
            current_date += timedelta(days=1)

        # Collect all side effects
        all_side_effects = []
        for event in med_events:
            if event.side_effect_note:
                all_side_effects.append({
                    'date': event.scheduled_at.strftime('%Y-%m-%d'),
                    'medication': event.medication.drug_name,
                    'note': event.side_effect_note,
                })

        return {
            'total_doses_scheduled': total_doses,
            'doses_taken': taken_doses,
            'doses_missed': missed_doses,
            'doses_late': late_doses,
            'adherence_percentage': adherence_pct,
            'medication_analytics': med_analytics,
            'daily_adherence': daily_adherence,
            'side_effects': all_side_effects,
            'medications_list': [f"{m.drug_name} {m.strength}{m.strength_unit}" for m in medications],
        }

    def _calculate_timing_accuracy(self, events):
        """Calculate how accurately doses were taken on time"""
        taken_events = events.filter(status__in=['taken', 'late'])
        if not taken_events.exists():
            return 100

        on_time = 0
        for event in taken_events:
            if event.delay_minutes is not None and abs(event.delay_minutes) <= 30:
                on_time += 1
            elif event.status == 'taken':
                on_time += 1

        return (on_time / taken_events.count() * 100) if taken_events.count() > 0 else 100

    def _collect_vitals_data(self, period_start, period_end):
        """Collect comprehensive vitals data including extended vitals"""
        from health_profile.models import WatchVitals

        vitals = WatchVitals.objects.filter(
            user=self.user,
            recorded_at__date__gte=period_start,
            recorded_at__date__lte=period_end
        ).order_by('recorded_at')

        if not vitals.exists():
            return {
                'has_data': False,
                'heart_rate': {'data': [], 'avg': None, 'min': None, 'max': None},
                'blood_oxygen': {'data': [], 'avg': None, 'min': None, 'max': None},
                'hrv': {'data': [], 'avg': None, 'min': None, 'max': None},
                'extended_vitals': {},
            }

        # Heart rate data (for graph)
        heart_rate_data = []
        hr_values = []
        for v in vitals:
            if v.heart_rate:
                heart_rate_data.append({
                    'date': v.recorded_at.strftime('%Y-%m-%d'),
                    'time': v.recorded_at.strftime('%H:%M'),
                    'value': v.heart_rate,
                })
                hr_values.append(v.heart_rate)

        # Blood oxygen data (for graph)
        spo2_data = []
        spo2_values = []
        for v in vitals:
            if v.blood_oxygen:
                spo2_data.append({
                    'date': v.recorded_at.strftime('%Y-%m-%d'),
                    'time': v.recorded_at.strftime('%H:%M'),
                    'value': v.blood_oxygen,
                })
                spo2_values.append(v.blood_oxygen)

        # HRV data (for graph)
        hrv_data = []
        hrv_values = []
        for v in vitals:
            if v.hrv:
                hrv_data.append({
                    'date': v.recorded_at.strftime('%Y-%m-%d'),
                    'time': v.recorded_at.strftime('%H:%M'),
                    'value': v.hrv,
                })
                hrv_values.append(v.hrv)

        # === EXTENDED VITALS ===
        # Blood Pressure
        bp_systolic_values = []
        bp_diastolic_values = []
        for v in vitals:
            if v.blood_pressure_systolic and v.blood_pressure_diastolic:
                bp_systolic_values.append(v.blood_pressure_systolic)
                bp_diastolic_values.append(v.blood_pressure_diastolic)

        # Blood Glucose
        glucose_values = []
        for v in vitals:
            if v.blood_glucose:
                glucose_values.append(v.blood_glucose)

        # Body Temperature
        temp_values = []
        for v in vitals:
            if v.body_temperature:
                temp_values.append(v.body_temperature)

        # Walking Steadiness
        steadiness_values = []
        steadiness_classifications = []
        for v in vitals:
            if v.walking_steadiness_percent is not None:
                steadiness_values.append(v.walking_steadiness_percent)
            if v.walking_steadiness_classification:
                steadiness_classifications.append(v.walking_steadiness_classification)

        # VO2 Max
        vo2_values = []
        for v in vitals:
            if v.vo2_max:
                vo2_values.append(v.vo2_max)

        # AFib Detection
        afib_events = sum(1 for v in vitals if v.afib_detected)
        afib_burden_values = [v.afib_burden_percent for v in vitals if v.afib_burden_percent is not None]

        # Respiratory Rate
        resp_values = []
        for v in vitals:
            if v.respiratory_rate:
                resp_values.append(v.respiratory_rate)

        # Peripheral Perfusion Index
        ppi_values = []
        for v in vitals:
            if v.peripheral_perfusion_index:
                ppi_values.append(v.peripheral_perfusion_index)

        # Daily averages (for trend graph)
        daily_vitals = vitals.annotate(
            day=TruncDate('recorded_at')
        ).values('day').annotate(
            avg_hr=Avg('heart_rate'),
            min_hr=Min('heart_rate'),
            max_hr=Max('heart_rate'),
            avg_spo2=Avg('blood_oxygen'),
            avg_hrv=Avg('hrv'),
            avg_systolic=Avg('blood_pressure_systolic'),
            avg_diastolic=Avg('blood_pressure_diastolic'),
            avg_glucose=Avg('blood_glucose'),
            avg_temp=Avg('body_temperature'),
        ).order_by('day')

        # Classify blood pressure
        bp_classification = 'N/A'
        if bp_systolic_values and bp_diastolic_values:
            avg_sys = sum(bp_systolic_values) / len(bp_systolic_values)
            avg_dia = sum(bp_diastolic_values) / len(bp_diastolic_values)
            if avg_sys < 120 and avg_dia < 80:
                bp_classification = 'Normal'
            elif avg_sys < 130 and avg_dia < 80:
                bp_classification = 'Elevated'
            elif avg_sys < 140 or avg_dia < 90:
                bp_classification = 'High BP Stage 1'
            elif avg_sys >= 140 or avg_dia >= 90:
                bp_classification = 'High BP Stage 2'
            if avg_sys >= 180 or avg_dia >= 120:
                bp_classification = 'Hypertensive Crisis'

        # Classify glucose
        glucose_classification = 'N/A'
        if glucose_values:
            avg_glucose = sum(glucose_values) / len(glucose_values)
            if avg_glucose < 100:
                glucose_classification = 'Normal'
            elif avg_glucose < 126:
                glucose_classification = 'Pre-diabetic'
            else:
                glucose_classification = 'Diabetic Range'

        # VO2 Max fitness level
        vo2_fitness = 'N/A'
        if vo2_values:
            avg_vo2 = sum(vo2_values) / len(vo2_values)
            if avg_vo2 >= 45:
                vo2_fitness = 'Excellent'
            elif avg_vo2 >= 35:
                vo2_fitness = 'Good'
            elif avg_vo2 >= 25:
                vo2_fitness = 'Fair'
            else:
                vo2_fitness = 'Poor'

        # Walking steadiness assessment
        steadiness_status = 'N/A'
        if steadiness_classifications:
            # Get most recent classification
            steadiness_status = steadiness_classifications[-1]

        extended_vitals = {
            'blood_pressure': {
                'avg_systolic': sum(bp_systolic_values) / len(bp_systolic_values) if bp_systolic_values else None,
                'avg_diastolic': sum(bp_diastolic_values) / len(bp_diastolic_values) if bp_diastolic_values else None,
                'classification': bp_classification,
                'readings': len(bp_systolic_values),
            },
            'blood_glucose': {
                'avg': sum(glucose_values) / len(glucose_values) if glucose_values else None,
                'min': min(glucose_values) if glucose_values else None,
                'max': max(glucose_values) if glucose_values else None,
                'classification': glucose_classification,
                'readings': len(glucose_values),
            },
            'body_temperature': {
                'avg': sum(temp_values) / len(temp_values) if temp_values else None,
                'min': min(temp_values) if temp_values else None,
                'max': max(temp_values) if temp_values else None,
                'fever_detected': max(temp_values) > 37.8 if temp_values else False,
                'readings': len(temp_values),
            },
            'walking_steadiness': {
                'avg_percent': sum(steadiness_values) / len(steadiness_values) if steadiness_values else None,
                'classification': steadiness_status,
                'fall_risk': steadiness_status in ['Low', 'Very Low'] if steadiness_status != 'N/A' else None,
                'readings': len(steadiness_values),
            },
            'vo2_max': {
                'avg': sum(vo2_values) / len(vo2_values) if vo2_values else None,
                'fitness_level': vo2_fitness,
                'readings': len(vo2_values),
            },
            'afib': {
                'events_detected': afib_events,
                'avg_burden_percent': sum(afib_burden_values) / len(afib_burden_values) if afib_burden_values else None,
                'alert': afib_events > 0,
            },
            'respiratory_rate': {
                'avg': sum(resp_values) / len(resp_values) if resp_values else None,
                'readings': len(resp_values),
            },
            'perfusion_index': {
                'avg': sum(ppi_values) / len(ppi_values) if ppi_values else None,
                'readings': len(ppi_values),
            },
        }

        return {
            'has_data': True,
            'heart_rate': {
                'data': heart_rate_data,
                'avg': sum(hr_values) / len(hr_values) if hr_values else None,
                'min': min(hr_values) if hr_values else None,
                'max': max(hr_values) if hr_values else None,
                'daily_avg': [{'date': d['day'].strftime('%Y-%m-%d'), 'avg': d['avg_hr'], 'min': d['min_hr'], 'max': d['max_hr']} for d in daily_vitals if d['avg_hr']],
            },
            'blood_oxygen': {
                'data': spo2_data,
                'avg': sum(spo2_values) / len(spo2_values) if spo2_values else None,
                'min': min(spo2_values) if spo2_values else None,
                'max': max(spo2_values) if spo2_values else None,
                'daily_avg': [{'date': d['day'].strftime('%Y-%m-%d'), 'avg': d['avg_spo2']} for d in daily_vitals if d['avg_spo2']],
            },
            'hrv': {
                'data': hrv_data,
                'avg': sum(hrv_values) / len(hrv_values) if hrv_values else None,
                'min': min(hrv_values) if hrv_values else None,
                'max': max(hrv_values) if hrv_values else None,
                'daily_avg': [{'date': d['day'].strftime('%Y-%m-%d'), 'avg': d['avg_hrv']} for d in daily_vitals if d['avg_hrv']],
            },
            'extended_vitals': extended_vitals,
            'total_readings': vitals.count(),
        }

    def _collect_activity_data(self, period_start, period_end):
        """Collect activity data (steps, calories, exercise, etc.)"""
        from health_profile.models import WatchVitals

        vitals = WatchVitals.objects.filter(
            user=self.user,
            recorded_at__date__gte=period_start,
            recorded_at__date__lte=period_end
        ).order_by('recorded_at')

        if not vitals.exists():
            return {'has_data': False}

        # Collect daily activity data
        daily_steps = []
        daily_calories = []
        daily_distance = []
        daily_exercise = []
        daily_floors = []
        daily_stand = []

        # Group by day for daily totals
        from django.db.models.functions import TruncDate as TruncDateFunc
        daily_activity = vitals.annotate(
            day=TruncDateFunc('recorded_at')
        ).values('day').annotate(
            total_steps=Max('steps'),  # Use max as daily cumulative
            total_calories=Max('calories'),
            total_distance=Max('distance_km'),
            total_exercise=Max('exercise_minutes'),
            total_floors=Max('floors_climbed'),
            total_stand=Max('stand_minutes'),
        ).order_by('day')

        activity_records = []
        for day_data in daily_activity:
            if day_data['total_steps'] and day_data['total_steps'] > 0:
                activity_records.append({
                    'date': day_data['day'].strftime('%Y-%m-%d'),
                    'steps': day_data['total_steps'],
                    'calories': day_data['total_calories'] or 0,
                    'distance_km': day_data['total_distance'] or 0,
                    'exercise_minutes': day_data['total_exercise'] or 0,
                    'floors_climbed': day_data['total_floors'] or 0,
                    'stand_minutes': day_data['total_stand'] or 0,
                })
                daily_steps.append(day_data['total_steps'])
                if day_data['total_calories']:
                    daily_calories.append(day_data['total_calories'])
                if day_data['total_distance']:
                    daily_distance.append(day_data['total_distance'])
                if day_data['total_exercise']:
                    daily_exercise.append(day_data['total_exercise'])

        # Calculate activity level
        avg_steps = sum(daily_steps) / len(daily_steps) if daily_steps else 0
        activity_level = 'N/A'
        if avg_steps >= 10000:
            activity_level = 'Very Active'
        elif avg_steps >= 7500:
            activity_level = 'Active'
        elif avg_steps >= 5000:
            activity_level = 'Moderate'
        elif avg_steps >= 2500:
            activity_level = 'Low'
        else:
            activity_level = 'Sedentary'

        return {
            'has_data': len(activity_records) > 0,
            'records': activity_records,
            'avg_steps': avg_steps,
            'total_steps': sum(daily_steps) if daily_steps else 0,
            'min_steps': min(daily_steps) if daily_steps else 0,
            'max_steps': max(daily_steps) if daily_steps else 0,
            'avg_calories': sum(daily_calories) / len(daily_calories) if daily_calories else 0,
            'avg_distance_km': sum(daily_distance) / len(daily_distance) if daily_distance else 0,
            'avg_exercise_minutes': sum(daily_exercise) / len(daily_exercise) if daily_exercise else 0,
            'activity_level': activity_level,
            'days_tracked': len(activity_records),
            'step_goal_met_days': sum(1 for s in daily_steps if s >= 7500),  # 7500 step goal
        }

    def _collect_mobility_data(self, period_start, period_end):
        """Collect mobility metrics (walking asymmetry, speed, gait balance) - critical for PD"""
        from health_profile.models import WatchVitals

        vitals = WatchVitals.objects.filter(
            user=self.user,
            recorded_at__date__gte=period_start,
            recorded_at__date__lte=period_end
        ).order_by('recorded_at')

        if not vitals.exists():
            return {'has_data': False}

        # Collect mobility metrics
        asymmetry_values = []
        walking_speed_values = []
        double_support_values = []
        stair_ascent_values = []
        stair_descent_values = []
        six_min_walk_values = []

        for v in vitals:
            if v.walking_asymmetry_percent is not None:
                asymmetry_values.append(v.walking_asymmetry_percent)
            if v.walking_speed is not None:
                walking_speed_values.append(v.walking_speed)
            if v.double_support_time_percent is not None:
                double_support_values.append(v.double_support_time_percent)
            if v.stair_ascent_speed is not None:
                stair_ascent_values.append(v.stair_ascent_speed)
            if v.stair_descent_speed is not None:
                stair_descent_values.append(v.stair_descent_speed)
            if v.six_minute_walk_distance is not None:
                six_min_walk_values.append(v.six_minute_walk_distance)

        # Gait assessment based on asymmetry
        gait_status = 'N/A'
        if asymmetry_values:
            avg_asymmetry = sum(asymmetry_values) / len(asymmetry_values)
            if avg_asymmetry <= 5:
                gait_status = 'Normal'
            elif avg_asymmetry <= 10:
                gait_status = 'Mild Imbalance'
            elif avg_asymmetry <= 20:
                gait_status = 'Moderate Imbalance'
            else:
                gait_status = 'Significant Imbalance - Review Needed'

        # Balance assessment based on double support time
        balance_status = 'N/A'
        if double_support_values:
            avg_double_support = sum(double_support_values) / len(double_support_values)
            if avg_double_support <= 20:
                balance_status = 'Good Balance'
            elif avg_double_support <= 30:
                balance_status = 'Fair Balance'
            else:
                balance_status = 'Poor Balance - Fall Risk'

        # Walking speed assessment
        speed_status = 'N/A'
        if walking_speed_values:
            avg_speed = sum(walking_speed_values) / len(walking_speed_values)
            if avg_speed >= 1.2:
                speed_status = 'Normal'
            elif avg_speed >= 0.8:
                speed_status = 'Below Normal'
            else:
                speed_status = 'Slow - Mobility Concern'

        return {
            'has_data': len(asymmetry_values) > 0 or len(walking_speed_values) > 0,
            'walking_asymmetry': {
                'avg_percent': sum(asymmetry_values) / len(asymmetry_values) if asymmetry_values else None,
                'status': gait_status,
                'readings': len(asymmetry_values),
            },
            'walking_speed': {
                'avg_m_per_s': sum(walking_speed_values) / len(walking_speed_values) if walking_speed_values else None,
                'status': speed_status,
                'readings': len(walking_speed_values),
            },
            'double_support_time': {
                'avg_percent': sum(double_support_values) / len(double_support_values) if double_support_values else None,
                'status': balance_status,
                'readings': len(double_support_values),
            },
            'stair_climbing': {
                'avg_ascent_speed': sum(stair_ascent_values) / len(stair_ascent_values) if stair_ascent_values else None,
                'avg_descent_speed': sum(stair_descent_values) / len(stair_descent_values) if stair_descent_values else None,
                'readings': max(len(stair_ascent_values), len(stair_descent_values)),
            },
            'six_minute_walk': {
                'avg_distance_m': sum(six_min_walk_values) / len(six_min_walk_values) if six_min_walk_values else None,
                'max_distance_m': max(six_min_walk_values) if six_min_walk_values else None,
                'readings': len(six_min_walk_values),
            },
            'overall_mobility_assessment': gait_status if gait_status != 'N/A' else balance_status,
        }

    def _collect_sleep_data(self, period_start, period_end):
        """Collect sleep data for the period"""
        from health_profile.models import WatchVitals

        vitals = WatchVitals.objects.filter(
            user=self.user,
            recorded_at__date__gte=period_start,
            recorded_at__date__lte=period_end
        ).order_by('recorded_at')

        sleep_records = []
        total_hours = []
        quality_scores = []
        deep_sleep = []
        rem_sleep = []
        light_sleep = []
        awakenings_list = []

        for v in vitals:
            if v.total_sleep_hours:
                sleep_records.append({
                    'date': v.recorded_at.strftime('%Y-%m-%d'),
                    'total_hours': v.total_sleep_hours,
                    'quality': v.sleep_quality,
                    'deep_hours': v.deep_sleep_hours,
                    'rem_hours': v.rem_sleep_hours,
                    'light_hours': v.core_sleep_hours,
                    'awakenings': v.awakenings_count,
                })
                total_hours.append(v.total_sleep_hours)
                if v.sleep_quality:
                    # Convert quality to numeric (good=3, fair=2, poor=1)
                    quality_map = {'good': 3, 'fair': 2, 'poor': 1}
                    quality_scores.append(quality_map.get(v.sleep_quality.lower(), 2))
                if v.deep_sleep_hours:
                    deep_sleep.append(v.deep_sleep_hours)
                if v.rem_sleep_hours:
                    rem_sleep.append(v.rem_sleep_hours)
                if v.core_sleep_hours:
                    light_sleep.append(v.core_sleep_hours)
                if v.awakenings_count:
                    awakenings_list.append(v.awakenings_count)

        # Analyze sleep patterns
        patterns = []
        if len(total_hours) >= 3:
            avg_hours = sum(total_hours) / len(total_hours)
            if avg_hours < 6:
                patterns.append("Consistently getting less than recommended sleep")
            elif avg_hours > 9:
                patterns.append("Getting more than typical recommended sleep")
            else:
                patterns.append("Sleep duration is within healthy range")

            # Check for variability
            if max(total_hours) - min(total_hours) > 3:
                patterns.append("High variability in sleep duration - inconsistent schedule")

        return {
            'has_data': len(sleep_records) > 0,
            'records': sleep_records,
            'avg_hours': sum(total_hours) / len(total_hours) if total_hours else None,
            'min_hours': min(total_hours) if total_hours else None,
            'max_hours': max(total_hours) if total_hours else None,
            'avg_quality_score': sum(quality_scores) / len(quality_scores) if quality_scores else None,
            'avg_deep_sleep': sum(deep_sleep) / len(deep_sleep) if deep_sleep else None,
            'avg_rem_sleep': sum(rem_sleep) / len(rem_sleep) if rem_sleep else None,
            'avg_light_sleep': sum(light_sleep) / len(light_sleep) if light_sleep else None,
            'avg_awakenings': sum(awakenings_list) / len(awakenings_list) if awakenings_list else None,
            'patterns': patterns,
            'nights_tracked': len(sleep_records),
        }

    def _collect_fall_data(self, period_start, period_end):
        """Collect fall detection data for the period"""
        from health_profile.models import WatchVitals
        from .models import PatientObservation

        # Check WatchVitals for fall_detected flags
        vitals_falls = WatchVitals.objects.filter(
            user=self.user,
            recorded_at__date__gte=period_start,
            recorded_at__date__lte=period_end,
            fall_detected=True
        )

        # Check PatientObservation for fall observations
        fall_observations = PatientObservation.objects.filter(
            user=self.user,
            observed_at__date__gte=period_start,
            observed_at__date__lte=period_end,
            observation_type='fall'
        )

        fall_events = []

        # From vitals
        for v in vitals_falls:
            fall_events.append({
                'date': v.recorded_at.strftime('%Y-%m-%d'),
                'time': v.recorded_at.strftime('%H:%M'),
                'source': 'watch_sensor',
                'severity': 'unknown',
                'description': 'Fall detected by Apple Watch',
                'context': None,
            })

        # From observations
        for obs in fall_observations:
            fall_events.append({
                'date': obs.observed_at.strftime('%Y-%m-%d'),
                'time': obs.observed_at.strftime('%H:%M'),
                'source': 'patient_report',
                'severity': obs.severity,
                'description': obs.description,
                'context': obs.title,
            })

        return {
            'total_falls': len(fall_events),
            'events': fall_events,
            'requires_attention': len([f for f in fall_events if f['severity'] in ['severe', 'critical']]) > 0,
        }

    def _collect_biomarker_data(self, period_start, period_end):
        """Collect biomarker changes during the period with abnormality detection"""
        from medical_reports.models import Biomarker

        biomarkers = Biomarker.objects.filter(
            user=self.user,
            test_date__gte=period_start,
            test_date__lte=period_end
        ).order_by('name', 'test_date')

        # Group by biomarker name
        biomarker_trends = {}
        abnormalities = []
        critical_abnormalities = []

        for b in biomarkers:
            if b.name not in biomarker_trends:
                biomarker_trends[b.name] = {
                    'values': [],
                    'unit': b.unit,
                    'reference_min': float(b.reference_min) if b.reference_min else None,
                    'reference_max': float(b.reference_max) if b.reference_max else None,
                    'category': b.category if hasattr(b, 'category') else 'general',
                }

            value = float(b.value) if b.value else None
            ref_min = float(b.reference_min) if b.reference_min else None
            ref_max = float(b.reference_max) if b.reference_max else None

            # Determine if value is abnormal
            status = 'normal'
            severity = 'normal'
            if value is not None:
                if ref_min is not None and value < ref_min:
                    status = 'low'
                    # Calculate severity based on how far below reference
                    if ref_min > 0:
                        deviation = ((ref_min - value) / ref_min) * 100
                        if deviation > 30:
                            severity = 'critical'
                        elif deviation > 15:
                            severity = 'moderate'
                        else:
                            severity = 'mild'
                elif ref_max is not None and value > ref_max:
                    status = 'high'
                    # Calculate severity based on how far above reference
                    if ref_max > 0:
                        deviation = ((value - ref_max) / ref_max) * 100
                        if deviation > 30:
                            severity = 'critical'
                        elif deviation > 15:
                            severity = 'moderate'
                        else:
                            severity = 'mild'

            biomarker_trends[b.name]['values'].append({
                'date': b.test_date.strftime('%Y-%m-%d') if b.test_date else None,
                'value': value,
                'status': status,
                'severity': severity,
            })

            # Track abnormalities
            if status != 'normal':
                abnormality_entry = {
                    'name': b.name,
                    'value': value,
                    'unit': b.unit,
                    'status': status,
                    'severity': severity,
                    'reference_range': f"{ref_min or 'N/A'} - {ref_max or 'N/A'}",
                    'date': b.test_date.strftime('%Y-%m-%d') if b.test_date else None,
                }
                abnormalities.append(abnormality_entry)
                if severity in ['moderate', 'critical']:
                    critical_abnormalities.append(abnormality_entry)

        # Calculate trend direction and abnormality status for each biomarker
        for name, data in biomarker_trends.items():
            values = [v['value'] for v in data['values'] if v['value'] is not None]
            statuses = [v['status'] for v in data['values']]

            # Trend direction
            if len(values) >= 2:
                if values[-1] > values[0]:
                    data['trend_direction'] = 'increasing'
                elif values[-1] < values[0]:
                    data['trend_direction'] = 'decreasing'
                else:
                    data['trend_direction'] = 'stable'
            else:
                data['trend_direction'] = 'insufficient_data'

            # Overall status (most recent value)
            data['current_status'] = statuses[-1] if statuses else 'unknown'
            data['latest_value'] = values[-1] if values else None

            # Count abnormal readings
            data['abnormal_count'] = sum(1 for s in statuses if s != 'normal')
            data['total_readings'] = len(statuses)

        return {
            'has_data': len(biomarker_trends) > 0,
            'biomarkers': biomarker_trends,
            'new_tests_count': biomarkers.count(),
            'abnormalities': abnormalities,
            'critical_abnormalities': critical_abnormalities,
            'abnormal_count': len(abnormalities),
            'critical_count': len(critical_abnormalities),
        }

    def _collect_clinical_data(self, period_start, period_end):
        """
        Collect clinical data per Reports.md specification:
        - Motor symptoms (bradykinesia, tremor, rigidity, gait, laterality)
        - Non-motor symptoms (sleep, constipation, mood, fatigue, etc.)
        - Safety events (falls, hallucinations, rapid worsening)
        - Speech metrics (voice volume, articulation, etc.)
        - Cognitive screening (MoCA-lite, PHQ-9)
        """
        try:
            from health_profile.models import (
                MotorSymptomEntry, NonMotorSymptomEntry, SafetyEvent,
                SpeechMetrics, CognitiveScreening
            )

            # Motor symptoms
            motor_symptoms = MotorSymptomEntry.objects.filter(
                user=self.user,
                recorded_date__gte=period_start,
                recorded_date__lte=period_end
            ).order_by('recorded_date')

            motor_data = []
            motor_totals = {'bradykinesia': [], 'tremor': [], 'rigidity': [], 'gait': []}
            laterality_counts = {'L': 0, 'R': 0, 'B': 0}

            for m in motor_symptoms:
                motor_data.append({
                    'date': m.recorded_date.isoformat(),
                    'bradykinesia': m.bradykinesia,
                    'tremor': m.tremor,
                    'rigidity': m.rigidity,
                    'gait_difficulty': m.gait_difficulty,
                    'laterality': m.laterality,
                    'data_source': m.data_source,
                })
                if m.bradykinesia:
                    motor_totals['bradykinesia'].append(m.bradykinesia)
                if m.tremor:
                    motor_totals['tremor'].append(m.tremor)
                if m.rigidity:
                    motor_totals['rigidity'].append(m.rigidity)
                if m.gait_difficulty:
                    motor_totals['gait'].append(m.gait_difficulty)
                if m.laterality:
                    laterality_counts[m.laterality] = laterality_counts.get(m.laterality, 0) + 1

            # Non-motor symptoms
            non_motor_symptoms = NonMotorSymptomEntry.objects.filter(
                user=self.user,
                recorded_date__gte=period_start,
                recorded_date__lte=period_end
            ).order_by('recorded_date')

            non_motor_data = []
            non_motor_totals = {'sleep': [], 'constipation': [], 'mood': [], 'fatigue': [], 'dizziness': []}

            for nm in non_motor_symptoms:
                non_motor_data.append({
                    'date': nm.recorded_date.isoformat(),
                    'sleep_quality': nm.sleep_quality,
                    'constipation': nm.constipation,
                    'mood': nm.mood,
                    'fatigue': nm.fatigue,
                    'dizziness': nm.dizziness,
                    'smell_loss': nm.smell_loss,
                    'rem_behavior': nm.rem_behavior,
                })
                if nm.sleep_quality:
                    non_motor_totals['sleep'].append(nm.sleep_quality)
                if nm.constipation:
                    non_motor_totals['constipation'].append(nm.constipation)
                if nm.mood:
                    non_motor_totals['mood'].append(nm.mood)
                if nm.fatigue:
                    non_motor_totals['fatigue'].append(nm.fatigue)
                if nm.dizziness:
                    non_motor_totals['dizziness'].append(nm.dizziness)

            # Safety events
            safety_events = SafetyEvent.objects.filter(
                user=self.user,
                occurred_at__date__gte=period_start,
                occurred_at__date__lte=period_end
            ).order_by('-occurred_at')

            safety_data = []
            event_counts = {'fall': 0, 'hallucination': 0, 'rapid_worsening': 0, 'autonomic_severe': 0, 'other': 0}

            for se in safety_events:
                safety_data.append({
                    'event_type': se.event_type,
                    'severity': se.severity,
                    'description': se.description,
                    'occurred_at': se.occurred_at.isoformat(),
                    'injury_sustained': se.injury_sustained,
                })
                event_counts[se.event_type] = event_counts.get(se.event_type, 0) + 1

            # === SPEECH METRICS ===
            speech_metrics = SpeechMetrics.objects.filter(
                user=self.user,
                recorded_date__gte=period_start,
                recorded_date__lte=period_end
            ).order_by('-recorded_date')

            speech_data = {
                'has_data': speech_metrics.exists(),
                'records': [],
                'avg_volume': None,
                'avg_articulation': None,
                'avg_variability': None,
                'avg_speech_rate': None,
            }

            if speech_metrics.exists():
                volume_vals = []
                articulation_vals = []
                variability_vals = []
                rate_vals = []

                for sm in speech_metrics:
                    speech_data['records'].append({
                        'date': sm.recorded_date.isoformat(),
                        'voice_volume': sm.voice_volume,
                        'articulation_clarity': sm.articulation_clarity,
                        'speech_variability': sm.speech_variability,
                        'speech_rate_wpm': sm.speech_rate_wpm,
                        'pause_duration_avg': sm.pause_duration_avg,
                    })
                    if sm.voice_volume:
                        volume_vals.append(sm.voice_volume)
                    if sm.articulation_clarity:
                        articulation_vals.append(sm.articulation_clarity)
                    if sm.speech_variability:
                        variability_vals.append(sm.speech_variability)
                    if sm.speech_rate_wpm:
                        rate_vals.append(sm.speech_rate_wpm)

                speech_data['avg_volume'] = sum(volume_vals) / len(volume_vals) if volume_vals else None
                speech_data['avg_articulation'] = sum(articulation_vals) / len(articulation_vals) if articulation_vals else None
                speech_data['avg_variability'] = sum(variability_vals) / len(variability_vals) if variability_vals else None
                speech_data['avg_speech_rate'] = sum(rate_vals) / len(rate_vals) if rate_vals else None

                # Speech status assessment
                if speech_data['avg_articulation']:
                    if speech_data['avg_articulation'] >= 4:
                        speech_data['status'] = 'Normal'
                    elif speech_data['avg_articulation'] >= 3:
                        speech_data['status'] = 'Mild Impairment'
                    elif speech_data['avg_articulation'] >= 2:
                        speech_data['status'] = 'Moderate Impairment'
                    else:
                        speech_data['status'] = 'Significant Impairment'

            # === COGNITIVE SCREENING ===
            cognitive_screenings = CognitiveScreening.objects.filter(
                user=self.user,
                recorded_date__gte=period_start,
                recorded_date__lte=period_end
            ).order_by('-recorded_date')

            cognitive_data = {
                'has_data': cognitive_screenings.exists(),
                'moca_score': None,
                'moca_status': None,
                'phq9_score': None,
                'phq9_status': None,
                'requires_escalation': False,
            }

            if cognitive_screenings.exists():
                latest = cognitive_screenings.first()

                if latest.moca_lite_score is not None:
                    cognitive_data['moca_score'] = latest.moca_lite_score
                    if latest.moca_lite_score >= 26:
                        cognitive_data['moca_status'] = 'Normal'
                    elif latest.moca_lite_score >= 22:
                        cognitive_data['moca_status'] = 'Mild Cognitive Impairment'
                    elif latest.moca_lite_score >= 17:
                        cognitive_data['moca_status'] = 'Moderate Cognitive Impairment'
                    else:
                        cognitive_data['moca_status'] = 'Severe Cognitive Impairment'

                if latest.phq9_total_score is not None:
                    cognitive_data['phq9_score'] = latest.phq9_total_score
                    if latest.phq9_total_score <= 4:
                        cognitive_data['phq9_status'] = 'Minimal Depression'
                    elif latest.phq9_total_score <= 9:
                        cognitive_data['phq9_status'] = 'Mild Depression'
                    elif latest.phq9_total_score <= 14:
                        cognitive_data['phq9_status'] = 'Moderate Depression'
                    elif latest.phq9_total_score <= 19:
                        cognitive_data['phq9_status'] = 'Moderately Severe Depression'
                    else:
                        cognitive_data['phq9_status'] = 'Severe Depression'

                # Check for suicidal ideation escalation (PHQ-9 Q9 >= 2)
                if hasattr(latest, 'phq9_q9_score') and latest.phq9_q9_score is not None:
                    if latest.phq9_q9_score >= 2:
                        cognitive_data['requires_escalation'] = True
                        cognitive_data['escalation_reason'] = 'PHQ-9 Q9 suicidal ideation score >= 2'

            # Calculate averages
            motor_averages = {
                k: sum(v) / len(v) if v else None
                for k, v in motor_totals.items()
            }
            non_motor_averages = {
                k: sum(v) / len(v) if v else None
                for k, v in non_motor_totals.items()
            }

            # Determine predominant laterality
            predominant_laterality = max(laterality_counts, key=laterality_counts.get) if any(laterality_counts.values()) else None

            # Calculate data completeness per Reports.md Section 6
            days_in_period = (period_end - period_start).days + 1
            motor_days = motor_symptoms.count()
            completeness = min(100, (motor_days / days_in_period) * 100) if days_in_period > 0 else 0

            # Check for bradykinesia (required per Reports.md)
            bradykinesia_assessed = len(motor_totals['bradykinesia']) > 0

            return {
                'has_data': len(motor_data) > 0 or len(non_motor_data) > 0 or len(safety_data) > 0,
                'motor_symptoms': motor_data,
                'motor_averages': motor_averages,
                'non_motor_symptoms': non_motor_data,
                'non_motor_averages': non_motor_averages,
                'safety_events': safety_data,
                'safety_event_counts': event_counts,
                'predominant_laterality': predominant_laterality,
                'data_completeness': round(completeness, 1),
                'bradykinesia_assessed': bradykinesia_assessed,
                'motor_days_tracked': motor_days,
                'total_safety_events': len(safety_data),
                # NEW: Speech and cognitive data
                'speech_metrics': speech_data,
                'cognitive_screening': cognitive_data,
            }
        except Exception as e:
            logger.error(f"Error collecting clinical data: {e}")
            return {
                'has_data': False,
                'motor_symptoms': [],
                'motor_averages': {},
                'non_motor_symptoms': [],
                'non_motor_averages': {},
                'safety_events': [],
                'safety_event_counts': {},
                'data_completeness': 0,
                'speech_metrics': {'has_data': False},
                'cognitive_screening': {'has_data': False},
            }

    def _collect_conversation_data(self, period_start, period_end):
        """
        Collect conversation history and observations from agent interactions.
        Includes topics discussed, concerns raised, and insights gathered.
        """
        try:
            from .models import PatientObservation

            # Collect agent observations
            observations = PatientObservation.objects.filter(
                user=self.user,
                observed_at__date__gte=period_start,
                observed_at__date__lte=period_end
            ).order_by('observed_at')

            # Group by type
            topics_discussed = {}
            concerns_raised = []
            mood_observations = []
            symptom_mentions = []

            for obs in observations:
                obs_type = obs.observation_type or 'general'
                if obs_type not in topics_discussed:
                    topics_discussed[obs_type] = []
                topics_discussed[obs_type].append({
                    'date': obs.observed_at.strftime('%Y-%m-%d'),
                    'title': obs.title,
                    'description': obs.description,
                    'severity': obs.severity,
                })

                if obs.requires_attention or obs.severity in ['severe', 'critical']:
                    concerns_raised.append({
                        'date': obs.observed_at.strftime('%Y-%m-%d'),
                        'type': obs_type,
                        'description': obs.description,
                        'severity': obs.severity,
                    })

                if obs_type == 'mood':
                    mood_observations.append({
                        'date': obs.observed_at.strftime('%Y-%m-%d'),
                        'value': obs.value,
                        'description': obs.description,
                    })

                if obs_type in ['symptom', 'side_effect', 'pain', 'discomfort']:
                    symptom_mentions.append({
                        'date': obs.observed_at.strftime('%Y-%m-%d'),
                        'title': obs.title,
                        'description': obs.description,
                    })

            # Calculate engagement metrics
            total_conversations = observations.count()
            days_with_conversations = observations.dates('observed_at', 'day').count()

            return {
                'has_data': total_conversations > 0,
                'total_conversations': total_conversations,
                'days_with_conversations': days_with_conversations,
                'topics_discussed': topics_discussed,
                'concerns_raised': concerns_raised,
                'mood_observations': mood_observations,
                'symptom_mentions': symptom_mentions,
                'topic_counts': {k: len(v) for k, v in topics_discussed.items()},
            }
        except Exception as e:
            logger.error(f"Error collecting conversation data: {e}")
            return {
                'has_data': False,
                'total_conversations': 0,
                'topics_discussed': {},
                'concerns_raised': [],
            }

    def _collect_medical_reports(self, period_start, period_end):
        """
        Collect and summarize medical reports uploaded during the period.
        Includes lab results, imaging, and clinical notes.
        """
        try:
            from medical_reports.models import UploadedMedicalReport

            reports = UploadedMedicalReport.objects.filter(
                user=self.user,
                uploaded_at__date__gte=period_start,
                uploaded_at__date__lte=period_end
            ).order_by('-uploaded_at')

            report_summaries = []
            report_types = {}

            for report in reports:
                report_type = report.file_type or 'other'
                if report_type not in report_types:
                    report_types[report_type] = 0
                report_types[report_type] += 1

                # Combine diagnoses and doctor_notes for findings
                findings = []
                if report.diagnoses:
                    findings.append(f"Diagnoses: {report.diagnoses}")
                if report.doctor_notes:
                    findings.append(f"Notes: {report.doctor_notes}")

                summary = {
                    'date': report.report_date.strftime('%Y-%m-%d') if report.report_date else report.uploaded_at.strftime('%Y-%m-%d'),
                    'type': report_type,
                    'title': report.file_name or 'Medical Report',
                    'findings': '; '.join(findings) if findings else None,
                    'status': 'processed' if report.is_processed else 'pending',
                    'provider': report.provider_name,
                    'facility': report.facility_name,
                }
                report_summaries.append(summary)

            return {
                'has_data': len(report_summaries) > 0,
                'total_reports': len(report_summaries),
                'reports': report_summaries[:10],  # Limit to most recent 10
                'report_types': report_types,
            }
        except Exception as e:
            logger.error(f"Error collecting medical reports: {e}")
            return {
                'has_data': False,
                'total_reports': 0,
                'reports': [],
            }

    def _analyze_trends(self, report_data, period_start, period_end):
        """
        Analyze trends and patterns across all data sources.
        Identifies correlations, worsening/improving trends, and patterns.
        """
        trends = {
            'symptom_trends': [],
            'medication_patterns': [],
            'vitals_trends': [],
            'sleep_patterns': [],
            'correlations': [],
            'concerning_patterns': [],
            'improving_patterns': [],
        }

        try:
            # Analyze motor symptom trends
            clinical_data = report_data.get('clinical_data', {})
            motor_symptoms = clinical_data.get('motor_symptoms', [])

            if len(motor_symptoms) >= 3:
                # Check for worsening bradykinesia
                brady_values = [m.get('bradykinesia') for m in motor_symptoms if m.get('bradykinesia')]
                if len(brady_values) >= 3:
                    first_half_avg = sum(brady_values[:len(brady_values)//2]) / (len(brady_values)//2)
                    second_half_avg = sum(brady_values[len(brady_values)//2:]) / (len(brady_values) - len(brady_values)//2)

                    if second_half_avg > first_half_avg + 0.5:
                        trends['concerning_patterns'].append("Bradykinesia showing worsening trend")
                        trends['symptom_trends'].append({
                            'symptom': 'bradykinesia',
                            'direction': 'worsening',
                            'change': f"+{(second_half_avg - first_half_avg):.1f}",
                        })
                    elif second_half_avg < first_half_avg - 0.5:
                        trends['improving_patterns'].append("Bradykinesia showing improvement")
                        trends['symptom_trends'].append({
                            'symptom': 'bradykinesia',
                            'direction': 'improving',
                            'change': f"{(second_half_avg - first_half_avg):.1f}",
                        })

            # Analyze medication adherence patterns
            med_data = report_data.get('medication_data', {})
            daily_adherence = med_data.get('daily_adherence', [])

            if len(daily_adherence) >= 7:
                # Check for weekend vs weekday patterns
                weekday_adherence = []
                weekend_adherence = []
                for day in daily_adherence:
                    day_date = datetime.strptime(day['date'], '%Y-%m-%d')
                    if day_date.weekday() >= 5:  # Weekend
                        weekend_adherence.append(day['adherence_pct'])
                    else:
                        weekday_adherence.append(day['adherence_pct'])

                if weekday_adherence and weekend_adherence:
                    weekday_avg = sum(weekday_adherence) / len(weekday_adherence)
                    weekend_avg = sum(weekend_adherence) / len(weekend_adherence)

                    if weekday_avg - weekend_avg > 15:
                        trends['medication_patterns'].append({
                            'pattern': 'weekend_drop',
                            'description': f"Adherence drops on weekends ({weekend_avg:.0f}% vs {weekday_avg:.0f}% weekdays)",
                        })
                        trends['concerning_patterns'].append("Medication adherence significantly lower on weekends")

            # Analyze sleep and symptom correlations
            sleep_data = report_data.get('sleep_data', {})
            if sleep_data.get('has_data') and clinical_data.get('has_data'):
                avg_sleep = sleep_data.get('avg_hours', 0) or 0
                motor_avg = clinical_data.get('motor_averages', {})
                avg_brady = motor_avg.get('bradykinesia', 0) or 0

                if avg_sleep < 6 and avg_brady > 3:
                    trends['correlations'].append({
                        'factors': ['poor_sleep', 'high_bradykinesia'],
                        'description': "Poor sleep quality correlated with elevated motor symptoms",
                    })

            # Analyze safety event patterns
            safety_events = clinical_data.get('safety_events', [])
            if len(safety_events) >= 2:
                trends['concerning_patterns'].append(f"{len(safety_events)} safety events recorded - requires attention")

            # Analyze vitals trends
            vitals_data = report_data.get('vitals_data', {})
            if vitals_data.get('has_data'):
                hr_data = vitals_data.get('heart_rate', {}).get('daily_avg', [])
                if len(hr_data) >= 5:
                    first_avg = sum(d['avg'] for d in hr_data[:len(hr_data)//2]) / (len(hr_data)//2)
                    second_avg = sum(d['avg'] for d in hr_data[len(hr_data)//2:]) / (len(hr_data) - len(hr_data)//2)

                    if abs(second_avg - first_avg) > 10:
                        direction = 'increasing' if second_avg > first_avg else 'decreasing'
                        trends['vitals_trends'].append({
                            'vital': 'heart_rate',
                            'direction': direction,
                            'change': f"{second_avg - first_avg:+.0f} bpm",
                        })

        except Exception as e:
            logger.error(f"Error analyzing trends: {e}")

        return trends

    def _calculate_health_scores(self, report_data):
        """Calculate health scores based on collected data including clinical symptoms"""
        scores = {
            'adherence_score': 0,
            'sleep_score': 0,
            'vitals_score': 0,
            'clinical_score': 0,
            'overall_score': 0,
        }

        # Adherence score (based on medication adherence percentage)
        med_data = report_data.get('medication_data', {})
        adherence_pct = med_data.get('adherence_percentage', 0)
        scores['adherence_score'] = min(100, int(adherence_pct))

        # Sleep score (based on average hours and quality)
        sleep_data = report_data.get('sleep_data', {})
        if sleep_data.get('has_data'):
            avg_hours = sleep_data.get('avg_hours', 0) or 0
            quality_score = sleep_data.get('avg_quality_score', 2) or 2

            # Hours score (7-9 hours is optimal)
            if 7 <= avg_hours <= 9:
                hours_score = 100
            elif 6 <= avg_hours < 7 or 9 < avg_hours <= 10:
                hours_score = 80
            else:
                hours_score = max(0, 60 - abs(avg_hours - 7.5) * 10)

            # Quality score (1-3 scale to 0-100)
            quality_pct = (quality_score / 3) * 100

            scores['sleep_score'] = int((hours_score + quality_pct) / 2)
        else:
            scores['sleep_score'] = 50  # Neutral if no data

        # Vitals score (based on heart rate and SpO2)
        vitals_data = report_data.get('vitals_data', {})
        if vitals_data.get('has_data'):
            hr_score = 100
            spo2_score = 100

            # Heart rate (60-100 is normal)
            avg_hr = vitals_data.get('heart_rate', {}).get('avg')
            if avg_hr:
                if 60 <= avg_hr <= 100:
                    hr_score = 100
                elif 50 <= avg_hr < 60 or 100 < avg_hr <= 110:
                    hr_score = 80
                else:
                    hr_score = 60

            # SpO2 (95+ is normal)
            avg_spo2 = vitals_data.get('blood_oxygen', {}).get('avg')
            if avg_spo2:
                if avg_spo2 >= 95:
                    spo2_score = 100
                elif avg_spo2 >= 92:
                    spo2_score = 75
                else:
                    spo2_score = 50

            scores['vitals_score'] = int((hr_score + spo2_score) / 2)
        else:
            scores['vitals_score'] = 50  # Neutral if no data

        # Clinical score (based on motor/non-motor symptoms and safety events)
        clinical_data = report_data.get('clinical_data', {})
        if clinical_data.get('has_data'):
            clinical_score = 100

            # Motor symptoms (lower is better, scale 1-5)
            motor_avg = clinical_data.get('motor_averages', {})
            avg_brady = motor_avg.get('bradykinesia', 0) or 0
            avg_tremor = motor_avg.get('tremor', 0) or 0
            avg_rigidity = motor_avg.get('rigidity', 0) or 0
            avg_gait = motor_avg.get('gait', 0) or 0

            # Calculate average motor severity (1-5) and convert to score
            motor_values = [v for v in [avg_brady, avg_tremor, avg_rigidity, avg_gait] if v > 0]
            if motor_values:
                avg_motor = sum(motor_values) / len(motor_values)
                # Convert 1-5 scale to score (1=100, 3=60, 5=20)
                motor_score = max(0, 120 - (avg_motor * 20))
                clinical_score = min(clinical_score, motor_score)

            # Safety events reduce score significantly
            safety_events = clinical_data.get('total_safety_events', 0)
            if safety_events > 0:
                clinical_score = max(0, clinical_score - (safety_events * 15))

            # Data completeness affects score
            completeness = clinical_data.get('data_completeness', 0)
            if completeness < 60:  # Below Reports.md threshold
                clinical_score = max(0, clinical_score - 10)

            scores['clinical_score'] = int(clinical_score)
        else:
            scores['clinical_score'] = 50  # Neutral if no data

        # Overall score (weighted average including clinical)
        scores['overall_score'] = int(
            scores['adherence_score'] * 0.25 +
            scores['sleep_score'] * 0.20 +
            scores['vitals_score'] * 0.20 +
            scores['clinical_score'] * 0.35  # Clinical most important for PD
        )

        return scores

    def _generate_ai_analysis(self, report_data, report_type):
        """Generate comprehensive AI analysis for the report using ALL data sources"""
        try:
            # Prepare data summary for AI
            med_data = report_data.get('medication_data', {})
            vitals_data = report_data.get('vitals_data', {})
            sleep_data = report_data.get('sleep_data', {})
            fall_data = report_data.get('fall_data', {})
            biomarker_data = report_data.get('biomarker_data', {})
            observations = report_data.get('observations', {})
            scores = report_data.get('scores', {})
            # NEW data sources
            clinical_data = report_data.get('clinical_data', {})
            conversation_data = report_data.get('conversation_data', {})
            medical_reports = report_data.get('medical_reports', {})
            trends = report_data.get('trends', {})
            # Extended data sources (added for comprehensive PD monitoring)
            activity_data = report_data.get('activity_data', {})
            mobility_data = report_data.get('mobility_data', {})
            extended_vitals = vitals_data.get('extended_vitals', {})
            speech_data = clinical_data.get('speech_metrics', {})
            cognitive_data = clinical_data.get('cognitive_screening', {})

            prompt = f"""You are a clinical AI assistant for Parkinson's Disease monitoring. Analyze ALL available patient data and create a detailed {report_type} report that helps the neurologist make informed decisions.

=== PARKINSON'S MOTOR SYMPTOMS (per Reports.md) ===
- Data Completeness: {clinical_data.get('data_completeness', 0)}%
- Days Tracked: {clinical_data.get('motor_days_tracked', 0)}
- Bradykinesia Assessed: {'Yes' if clinical_data.get('bradykinesia_assessed') else 'NO - CRITICAL MISSING DATA'}
- Predominant Laterality: {clinical_data.get('predominant_laterality', 'Not recorded')}

Motor Symptom Averages (1-5 scale, 5=severe):
- Bradykinesia: {clinical_data.get('motor_averages', {}).get('bradykinesia', 'N/A')}
- Tremor: {clinical_data.get('motor_averages', {}).get('tremor', 'N/A')}
- Rigidity: {clinical_data.get('motor_averages', {}).get('rigidity', 'N/A')}
- Gait Difficulty: {clinical_data.get('motor_averages', {}).get('gait', 'N/A')}

Motor Symptom History: {json.dumps(clinical_data.get('motor_symptoms', [])[:7])}

=== NON-MOTOR SYMPTOMS ===
Non-Motor Averages (1-5 scale):
- Sleep Disturbance: {clinical_data.get('non_motor_averages', {}).get('sleep', 'N/A')}
- Constipation: {clinical_data.get('non_motor_averages', {}).get('constipation', 'N/A')}
- Mood/Apathy: {clinical_data.get('non_motor_averages', {}).get('mood', 'N/A')}
- Fatigue: {clinical_data.get('non_motor_averages', {}).get('fatigue', 'N/A')}
- Dizziness: {clinical_data.get('non_motor_averages', {}).get('dizziness', 'N/A')}

=== SAFETY EVENTS (RED FLAGS) ===
- Total Safety Events: {clinical_data.get('total_safety_events', 0)}
- Falls: {clinical_data.get('safety_event_counts', {}).get('fall', 0)}
- Hallucinations: {clinical_data.get('safety_event_counts', {}).get('hallucination', 0)}
- Rapid Worsening: {clinical_data.get('safety_event_counts', {}).get('rapid_worsening', 0)}
- Safety Event Details: {json.dumps(clinical_data.get('safety_events', [])[:5])}

=== MEDICATION ADHERENCE ===
- Medications: {', '.join(med_data.get('medications_list', [])) or 'None'}
- Total Scheduled Doses: {med_data.get('total_doses_scheduled', 0)}
- Doses Taken: {med_data.get('doses_taken', 0)} | Missed: {med_data.get('doses_missed', 0)} | Late: {med_data.get('doses_late', 0)}
- Adherence Rate: {med_data.get('adherence_percentage', 0):.1f}%
- Side Effects Reported: {json.dumps(med_data.get('side_effects', [])[:10])}

=== VITAL SIGNS (HealthKit/Apple Watch) ===
- Heart Rate: Avg {vitals_data.get('heart_rate', {}).get('avg', 'N/A')} bpm (Range: {vitals_data.get('heart_rate', {}).get('min', 'N/A')}-{vitals_data.get('heart_rate', {}).get('max', 'N/A')})
- Blood Oxygen (SpO2): Avg {vitals_data.get('blood_oxygen', {}).get('avg', 'N/A')}%
- Heart Rate Variability: Avg {vitals_data.get('hrv', {}).get('avg', 'N/A')} ms
- Total Readings: {vitals_data.get('total_readings', 0)}

=== EXTENDED VITALS (Cardiovascular & Metabolic) ===
- Blood Pressure: {extended_vitals.get('blood_pressure', {}).get('avg_systolic', 'N/A')}/{extended_vitals.get('blood_pressure', {}).get('avg_diastolic', 'N/A')} mmHg - {extended_vitals.get('blood_pressure', {}).get('classification', 'N/A')}
- Blood Glucose: {extended_vitals.get('blood_glucose', {}).get('avg', 'N/A')} mg/dL - {extended_vitals.get('blood_glucose', {}).get('classification', 'N/A')}
- Body Temperature: {extended_vitals.get('body_temperature', {}).get('avg', 'N/A')}°C - {extended_vitals.get('body_temperature', {}).get('status', 'N/A')}
- VO2 Max: {extended_vitals.get('vo2_max', {}).get('avg', 'N/A')} mL/kg/min - {extended_vitals.get('vo2_max', {}).get('fitness_level', 'N/A')}
- AFib Detection: {extended_vitals.get('afib', {}).get('total_events', 0)} events, Burden {extended_vitals.get('afib', {}).get('avg_burden', 0):.1f}%
- Walking Steadiness: {extended_vitals.get('walking_steadiness', {}).get('avg', 'N/A')}% - {extended_vitals.get('walking_steadiness', {}).get('classification', 'N/A')} (Fall Risk: {extended_vitals.get('walking_steadiness', {}).get('fall_risk', 'N/A')})
- Respiratory Rate: {extended_vitals.get('respiratory_rate', {}).get('avg', 'N/A')} breaths/min

=== ACTIVITY & STEPS DATA ===
- Average Daily Steps: {activity_data.get('avg_steps', 'N/A')} steps
- Activity Level: {activity_data.get('activity_level', 'N/A')}
- Step Goal Met (7500): {activity_data.get('step_goal_met_days', 0)}/{activity_data.get('days_tracked', 0)} days
- Daily Calories Burned: {activity_data.get('avg_calories', 'N/A')} kcal
- Daily Distance: {activity_data.get('avg_distance_km', 'N/A')} km
- Exercise Minutes/Day: {activity_data.get('avg_exercise_minutes', 'N/A')} min
- Floors Climbed/Day: {activity_data.get('avg_floors', 'N/A')}
- Stand Minutes/Day: {activity_data.get('avg_stand_minutes', 'N/A')} min
- Step Trend: {activity_data.get('step_trend', 'Stable')}

=== MOBILITY METRICS (Critical for Parkinson's) ===
- Walking Asymmetry: {mobility_data.get('walking_asymmetry', {}).get('avg', 'N/A')}% - {mobility_data.get('walking_asymmetry', {}).get('gait_status', 'N/A')}
- Walking Speed: {mobility_data.get('walking_speed', {}).get('avg', 'N/A')} m/s - {mobility_data.get('walking_speed', {}).get('status', 'N/A')}
- Double Support Time: {mobility_data.get('double_support_time', {}).get('avg', 'N/A')}% - {mobility_data.get('double_support_time', {}).get('balance_status', 'N/A')}
- Stair Ascent Speed: {mobility_data.get('stair_climbing', {}).get('avg_ascent_speed', 'N/A')} steps/min
- Stair Descent Speed: {mobility_data.get('stair_climbing', {}).get('avg_descent_speed', 'N/A')} steps/min
- Six-Minute Walk Distance: {mobility_data.get('six_minute_walk', {}).get('avg_distance', 'N/A')} m - {mobility_data.get('six_minute_walk', {}).get('status', 'N/A')}
- Mobility Trend: {mobility_data.get('mobility_trend', 'Stable')}

=== SPEECH ASSESSMENT (Parkinson's Voice Biomarker) ===
- Voice Volume: {speech_data.get('avg_volume', 'N/A')} - {speech_data.get('status', 'N/A')}
- Articulation Clarity: {speech_data.get('avg_articulation', 'N/A')}%
- Speech Variability: {speech_data.get('avg_variability', 'N/A')}
- Hypophonia Detected: {'Yes' if speech_data.get('avg_volume', 100) and speech_data.get('avg_volume', 100) < 60 else 'No'}
- Days with Speech Data: {speech_data.get('days_tracked', 0)}

=== COGNITIVE SCREENING ===
- MoCA-Lite Score: {cognitive_data.get('moca_score', 'N/A')}/30 - {cognitive_data.get('moca_status', 'N/A')}
- PHQ-9 Depression Score: {cognitive_data.get('phq9_score', 'N/A')}/27 - {cognitive_data.get('phq9_status', 'N/A')}
- Suicide Risk Flag (Q9≥2): {'YES - ESCALATE' if cognitive_data.get('requires_escalation') else 'No'}
- Last Screening Date: {cognitive_data.get('last_screening_date', 'N/A')}

=== SLEEP DATA ===
- Average Sleep: {sleep_data.get('avg_hours', 'N/A')} hours
- Sleep Quality Score: {sleep_data.get('avg_quality_score', 'N/A')}/3
- Deep Sleep: {sleep_data.get('avg_deep_sleep', 'N/A')} hours | REM: {sleep_data.get('avg_rem_sleep', 'N/A')} hours
- Average Awakenings: {sleep_data.get('avg_awakenings', 'N/A')}
- Sleep Patterns: {json.dumps(sleep_data.get('patterns', []))}

=== FALL EVENTS (from Watch & HealthKit) ===
- Total Falls: {fall_data.get('total_falls', 0)}
- Fall Events: {json.dumps(fall_data.get('events', [])[:5])}

=== LAB RESULTS & BIOMARKERS ===
{json.dumps(biomarker_data.get('biomarkers', {}), indent=2) if biomarker_data.get('has_data') else 'No new lab results'}

Critical Abnormalities: {json.dumps(biomarker_data.get('critical_abnormalities', [])) if biomarker_data.get('critical_count', 0) > 0 else 'None'}

=== CONVERSATION INSIGHTS (from AI Agent) ===
- Total Conversations: {conversation_data.get('total_conversations', 0)}
- Days with Engagement: {conversation_data.get('days_with_conversations', 0)}
- Topics Discussed: {json.dumps(conversation_data.get('topic_counts', {}))}
- Concerns Raised by Patient: {json.dumps(conversation_data.get('concerns_raised', [])[:5])}
- Mood Observations: {json.dumps(conversation_data.get('mood_observations', [])[:5])}
- Symptoms Mentioned: {json.dumps(conversation_data.get('symptom_mentions', [])[:5])}

=== MEDICAL REPORTS UPLOADED ===
- Total Reports: {medical_reports.get('total_reports', 0)}
- Report Types: {json.dumps(medical_reports.get('report_types', {}))}
- Recent Report Findings: {json.dumps([r.get('findings') for r in medical_reports.get('reports', [])[:3] if r.get('findings')])}

=== TREND ANALYSIS (Patterns Detected) ===
- Symptom Trends: {json.dumps(trends.get('symptom_trends', []))}
- Medication Patterns: {json.dumps(trends.get('medication_patterns', []))}
- Vitals Trends: {json.dumps(trends.get('vitals_trends', []))}
- Correlations Found: {json.dumps(trends.get('correlations', []))}
- CONCERNING PATTERNS: {json.dumps(trends.get('concerning_patterns', []))}
- IMPROVING PATTERNS: {json.dumps(trends.get('improving_patterns', []))}

=== HEALTH SCORES ===
- Overall Score: {scores.get('overall_score', 0)}/100
- Adherence Score: {scores.get('adherence_score', 0)}/100
- Sleep Score: {scores.get('sleep_score', 0)}/100
- Vitals Score: {scores.get('vitals_score', 0)}/100
- Clinical Score: {scores.get('clinical_score', 0)}/100

=== ANALYSIS INSTRUCTIONS ===
As a Parkinson's Disease specialist AI, analyze ALL data above and provide:

1. Look for correlations between motor symptoms and medication timing
2. Identify if medication is losing effectiveness (wearing-off patterns)
3. Note any concerning progression in motor or non-motor symptoms
4. Correlate sleep quality with next-day symptom severity
5. Identify patterns in safety events (time of day, medication timing)
6. Consider conversation insights for subjective patient experience
7. Flag any red flags per Reports.md specification
8. Analyze MOBILITY METRICS - walking asymmetry and gait balance are critical PD biomarkers
9. Assess ACTIVITY LEVELS - declining steps/exercise may indicate disease progression
10. Evaluate SPEECH PATTERNS - hypophonia (soft voice) is an early PD indicator
11. Review COGNITIVE SCREENING - MoCA and PHQ-9 scores for dementia and depression risk
12. Assess CARDIOVASCULAR RISK - BP, glucose, AFib for autonomic dysfunction
13. FLAG IMMEDIATELY if PHQ-9 Q9 score indicates suicide risk

Please provide a comprehensive analysis in the following JSON format:
{{
    "doctor_summary": "Executive summary for the neurologist (4-6 sentences highlighting PD progression, medication effectiveness, and key concerns)",
    "patient_summary": "Patient-friendly summary (2-3 sentences in simple language)",
    "clinical_assessment": "Detailed assessment of motor and non-motor symptom patterns, laterality, and disease progression",
    "medication_insights": "Analysis of medication adherence, timing, side effects, and potential wearing-off patterns",
    "sleep_analysis": "Sleep patterns and their correlation with symptom severity",
    "vitals_analysis": "Heart rate, HRV, SpO2, BP, glucose trends and autonomic function assessment",
    "activity_assessment": "Analysis of step counts, exercise levels, and their correlation with symptoms. Note declining activity as potential progression indicator",
    "mobility_assessment": "Gait analysis - walking asymmetry, speed, balance. Critical for detecting freezing of gait risk",
    "speech_assessment": "Voice changes - hypophonia, articulation. Early biomarker for PD progression",
    "cognitive_assessment": "MoCA and PHQ-9 interpretation, cognitive decline concerns, depression management",
    "cardiovascular_assessment": "BP patterns (orthostatic hypotension risk), glucose control, AFib burden for anticoagulation decisions",
    "side_effect_correlations": "Connections between medications and reported side effects",
    "trend_summary": "Summary of improving and worsening trends observed across all domains",
    "red_flags": ["List of safety events or concerning patterns requiring immediate attention - INCLUDE PHQ-9 Q9>=2"],
    "concerns": ["List of items requiring clinical attention at next visit"],
    "recommendations": ["Specific recommendations for the neurologist to consider - include referrals if needed (PT, speech therapy, psychiatry)"],
    "patient_tips": ["Simple tips for the patient to improve outcomes"],
    "data_gaps": ["Missing data that should be collected (per Reports.md requirements)"]
}}

Be specific, actionable, and clinically relevant. This report helps neurologists make treatment decisions for Parkinson's patients."""

            # Add timeout to prevent hanging (60 seconds max)
            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": """You are a specialized clinical AI assistant for Parkinson's Disease monitoring, trained on movement disorder neurology literature and the MDS-UPDRS clinical rating scales.

Your role is to analyze comprehensive patient data and create actionable clinical reports that help neurologists:
- Track disease progression over time
- Assess medication effectiveness and wearing-off patterns
- Identify concerning patterns requiring intervention
- Correlate symptoms with sleep, medication timing, and other factors
- Flag safety events (falls, hallucinations) for immediate attention

Follow Reports.md clinical guidelines:
- Bradykinesia is the core diagnostic feature and must always be assessed
- Laterality (L/R/Both) has diagnostic significance
- Safety events require immediate escalation
- Data completeness thresholds: Daily ≥60%, Weekly ≥4 days, Monthly ≥70%

Be professional, precise, and clinically actionable. Always respond in valid JSON format."""},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=4000,
                temperature=0.3,
                timeout=60.0  # 60 second timeout
            )

            ai_response = response.choices[0].message.content

            # Try to parse as JSON
            try:
                # Remove markdown code blocks if present
                if ai_response.startswith('```'):
                    ai_response = ai_response.split('```')[1]
                    if ai_response.startswith('json'):
                        ai_response = ai_response[4:]

                ai_analysis = json.loads(ai_response.strip())
            except json.JSONDecodeError:
                # Fallback to text parsing
                ai_analysis = {
                    'doctor_summary': ai_response[:500],
                    'patient_summary': 'Please review your health data with your doctor.',
                    'clinical_assessment': '',
                    'medication_insights': '',
                    'sleep_analysis': '',
                    'vitals_analysis': '',
                    'activity_assessment': '',
                    'mobility_assessment': '',
                    'speech_assessment': '',
                    'cognitive_assessment': '',
                    'cardiovascular_assessment': '',
                    'side_effect_correlations': '',
                    'trend_summary': '',
                    'red_flags': [],
                    'concerns': [],
                    'recommendations': [],
                    'patient_tips': [],
                    'data_gaps': [],
                }

            return ai_analysis

        except Exception as e:
            logger.error("OpenAI error in report generation: %s", e)
            return {
                'doctor_summary': f"Report for {report_data['period_start']} to {report_data['period_end']}. AI analysis unavailable.",
                'patient_summary': 'Your health data has been collected. Please discuss with your doctor.',
                'clinical_assessment': '',
                'medication_insights': f"Adherence rate: {med_data.get('adherence_percentage', 0):.1f}%",
                'sleep_analysis': '',
                'vitals_analysis': '',
                'activity_assessment': '',
                'mobility_assessment': '',
                'speech_assessment': '',
                'cognitive_assessment': '',
                'cardiovascular_assessment': '',
                'side_effect_correlations': '',
                'trend_summary': '',
                'red_flags': [],
                'concerns': [],
                'recommendations': ['Please review patient data manually.'],
                'patient_tips': ['Continue taking medications as prescribed.'],
                'data_gaps': [],
            }

    def save_report(self, report_data):
        """Save the generated report to the database and mark as completed"""
        from .models import PatientReport

        ai_analysis = report_data.get('ai_analysis', {})
        scores = report_data.get('scores', {})
        med_data = report_data.get('medication_data', {})
        sleep_data = report_data.get('sleep_data', {})
        vitals_data = report_data.get('vitals_data', {})
        fall_data = report_data.get('fall_data', {})
        biomarker_data = report_data.get('biomarker_data', {})
        observations = report_data.get('observations', {})
        # NEW: Activity, mobility, and clinical data
        activity_data = report_data.get('activity_data', {})
        mobility_data = report_data.get('mobility_data', {})
        clinical_data = report_data.get('clinical_data', {})
        trends_data = report_data.get('trends', {})

        # If we have a report instance (background generation), update it directly
        if self.report_instance:
            report = self.report_instance
            # Update all fields on the existing instance
            report.period_start = report_data['period_start']
            report.period_end = report_data['period_end']
            report.total_doses_scheduled = med_data.get('total_doses_scheduled', 0)
            report.doses_taken = med_data.get('doses_taken', 0)
            report.doses_missed = med_data.get('doses_missed', 0)
            report.doses_late = med_data.get('doses_late', 0)
            report.adherence_percentage = med_data.get('adherence_percentage', 0)
            report.side_effects_reported = med_data.get('side_effects', [])
            report.side_effects_count = len(med_data.get('side_effects', []))
            report.overall_health_score = scores.get('overall_score', 0)
            report.adherence_score = scores.get('adherence_score', 0)
            report.sleep_score = scores.get('sleep_score', 0)
            report.vitals_score = scores.get('vitals_score', 0)
            report.vitals_analytics = {
                'heart_rate': vitals_data.get('heart_rate', {}),
                'blood_oxygen': vitals_data.get('blood_oxygen', {}),
                'hrv': vitals_data.get('hrv', {}),
                'extended_vitals': vitals_data.get('extended_vitals', {}),
            }
            # NEW: Save activity, mobility, and clinical analytics
            report.activity_analytics = {
                'avg_steps': activity_data.get('avg_steps', 0),
                'total_steps': activity_data.get('total_steps', 0),
                'avg_calories': activity_data.get('avg_calories', 0),
                'avg_distance_km': activity_data.get('avg_distance_km', 0),
                'avg_exercise_minutes': activity_data.get('avg_exercise_minutes', 0),
                'activity_level': activity_data.get('activity_level', 'N/A'),
                'days_tracked': activity_data.get('days_tracked', 0),
                'step_goal_met_days': activity_data.get('step_goal_met_days', 0),
                'records': activity_data.get('records', [])[:30],  # Limit to 30 days
            }
            report.mobility_analytics = {
                'walking_asymmetry': mobility_data.get('walking_asymmetry', {}),
                'walking_speed': mobility_data.get('walking_speed', {}),
                'double_support_time': mobility_data.get('double_support_time', {}),
                'stair_climbing': mobility_data.get('stair_climbing', {}),
                'six_minute_walk': mobility_data.get('six_minute_walk', {}),
                'overall_assessment': mobility_data.get('overall_mobility_assessment', 'N/A'),
            }
            report.clinical_analytics = {
                'motor_symptoms': clinical_data.get('motor_symptoms', [])[:30],
                'motor_averages': clinical_data.get('motor_averages', {}),
                'non_motor_symptoms': clinical_data.get('non_motor_symptoms', [])[:30],
                'non_motor_averages': clinical_data.get('non_motor_averages', {}),
                'safety_events': clinical_data.get('safety_events', []),
                'safety_event_counts': clinical_data.get('safety_event_counts', {}),
                'data_completeness': clinical_data.get('data_completeness', 0),
                'predominant_laterality': clinical_data.get('predominant_laterality'),
                'speech_metrics': clinical_data.get('speech_metrics', {}),
                'cognitive_screening': clinical_data.get('cognitive_screening', {}),
                'trends': {
                    'symptom_trends': trends_data.get('symptom_trends', []),
                    'concerning_patterns': trends_data.get('concerning_patterns', []),
                    'improving_patterns': trends_data.get('improving_patterns', []),
                    'correlations': trends_data.get('correlations', []),
                },
            }
            report.sleep_analytics = {
                'records': sleep_data.get('records', []),
                'avg_hours': sleep_data.get('avg_hours'),
                'patterns': sleep_data.get('patterns', []),
                'stages': {
                    'deep': sleep_data.get('avg_deep_sleep'),
                    'rem': sleep_data.get('avg_rem_sleep'),
                    'light': sleep_data.get('avg_light_sleep'),
                },
            }
            report.fall_events = fall_data.get('events', [])
            report.fall_count = fall_data.get('total_falls', 0)
            report.medication_analytics = med_data.get('medication_analytics', {})
            report.biomarker_trends = {
                'biomarkers': biomarker_data.get('biomarkers', {}),
                'abnormalities': biomarker_data.get('abnormalities', []),
                'critical_abnormalities': biomarker_data.get('critical_abnormalities', []),
                'abnormal_count': biomarker_data.get('abnormal_count', 0),
                'critical_count': biomarker_data.get('critical_count', 0),
            }
            report.ai_summary = ai_analysis.get('doctor_summary', '')
            report.ai_observations = ', '.join(ai_analysis.get('concerns', []))
            report.ai_recommendations = ', '.join(ai_analysis.get('recommendations', []))
            report.ai_concerns = ', '.join(ai_analysis.get('concerns', []))
            report.ai_sleep_analysis = ai_analysis.get('sleep_analysis', '')
            report.ai_vitals_analysis = ai_analysis.get('vitals_analysis', '')
            report.ai_medication_insights = ai_analysis.get('medication_insights', '')
            report.ai_side_effect_correlations = ai_analysis.get('side_effect_correlations', '')
            report.ai_doctor_summary = ai_analysis.get('doctor_summary', '')
            report.ai_patient_summary = ai_analysis.get('patient_summary', '')
            report.conversation_count = observations.get('total_count', 0)
            # Mark as completed
            report.status = 'completed'
            report.progress = 100
            report.save()
            return report

        # Fallback to update_or_create for direct calls (non-background)
        report, created = PatientReport.objects.update_or_create(
            user=self.user,
            report_type=report_data['report_type'],
            report_date=report_data['period_end'],
            defaults={
                'period_start': report_data['period_start'],
                'period_end': report_data['period_end'],
                'status': 'completed',
                'progress': 100,
                # Medication stats
                'total_doses_scheduled': med_data.get('total_doses_scheduled', 0),
                'doses_taken': med_data.get('doses_taken', 0),
                'doses_missed': med_data.get('doses_missed', 0),
                'doses_late': med_data.get('doses_late', 0),
                'adherence_percentage': med_data.get('adherence_percentage', 0),
                'side_effects_reported': med_data.get('side_effects', []),
                'side_effects_count': len(med_data.get('side_effects', [])),
                # Scores
                'overall_health_score': scores.get('overall_score', 0),
                'adherence_score': scores.get('adherence_score', 0),
                'sleep_score': scores.get('sleep_score', 0),
                'vitals_score': scores.get('vitals_score', 0),
                # Analytics data (for graphs)
                'vitals_analytics': {
                    'heart_rate': vitals_data.get('heart_rate', {}),
                    'blood_oxygen': vitals_data.get('blood_oxygen', {}),
                    'hrv': vitals_data.get('hrv', {}),
                    'extended_vitals': vitals_data.get('extended_vitals', {}),
                },
                'sleep_analytics': {
                    'records': sleep_data.get('records', []),
                    'avg_hours': sleep_data.get('avg_hours'),
                    'patterns': sleep_data.get('patterns', []),
                    'stages': {
                        'deep': sleep_data.get('avg_deep_sleep'),
                        'rem': sleep_data.get('avg_rem_sleep'),
                        'light': sleep_data.get('avg_light_sleep'),
                    },
                },
                'fall_events': fall_data.get('events', []),
                'fall_count': fall_data.get('total_falls', 0),
                'medication_analytics': med_data.get('medication_analytics', {}),
                'biomarker_trends': {
                    'biomarkers': biomarker_data.get('biomarkers', {}),
                    'abnormalities': biomarker_data.get('abnormalities', []),
                    'critical_abnormalities': biomarker_data.get('critical_abnormalities', []),
                    'abnormal_count': biomarker_data.get('abnormal_count', 0),
                    'critical_count': biomarker_data.get('critical_count', 0),
                },
                # NEW: Activity, mobility, and clinical analytics
                'activity_analytics': {
                    'avg_steps': activity_data.get('avg_steps', 0),
                    'total_steps': activity_data.get('total_steps', 0),
                    'avg_calories': activity_data.get('avg_calories', 0),
                    'avg_distance_km': activity_data.get('avg_distance_km', 0),
                    'avg_exercise_minutes': activity_data.get('avg_exercise_minutes', 0),
                    'activity_level': activity_data.get('activity_level', 'N/A'),
                    'days_tracked': activity_data.get('days_tracked', 0),
                    'step_goal_met_days': activity_data.get('step_goal_met_days', 0),
                    'records': activity_data.get('records', [])[:30],
                },
                'mobility_analytics': {
                    'walking_asymmetry': mobility_data.get('walking_asymmetry', {}),
                    'walking_speed': mobility_data.get('walking_speed', {}),
                    'double_support_time': mobility_data.get('double_support_time', {}),
                    'stair_climbing': mobility_data.get('stair_climbing', {}),
                    'six_minute_walk': mobility_data.get('six_minute_walk', {}),
                    'overall_assessment': mobility_data.get('overall_mobility_assessment', 'N/A'),
                },
                'clinical_analytics': {
                    'motor_symptoms': clinical_data.get('motor_symptoms', [])[:30],
                    'motor_averages': clinical_data.get('motor_averages', {}),
                    'non_motor_symptoms': clinical_data.get('non_motor_symptoms', [])[:30],
                    'non_motor_averages': clinical_data.get('non_motor_averages', {}),
                    'safety_events': clinical_data.get('safety_events', []),
                    'safety_event_counts': clinical_data.get('safety_event_counts', {}),
                    'data_completeness': clinical_data.get('data_completeness', 0),
                    'predominant_laterality': clinical_data.get('predominant_laterality'),
                    'speech_metrics': clinical_data.get('speech_metrics', {}),
                    'cognitive_screening': clinical_data.get('cognitive_screening', {}),
                    'trends': {
                        'symptom_trends': trends_data.get('symptom_trends', []),
                        'concerning_patterns': trends_data.get('concerning_patterns', []),
                        'improving_patterns': trends_data.get('improving_patterns', []),
                        'correlations': trends_data.get('correlations', []),
                    },
                },
                # AI analysis
                'ai_summary': ai_analysis.get('doctor_summary', ''),
                'ai_observations': ', '.join(ai_analysis.get('concerns', [])),
                'ai_recommendations': ', '.join(ai_analysis.get('recommendations', [])),
                'ai_concerns': ', '.join(ai_analysis.get('concerns', [])),
                'ai_sleep_analysis': ai_analysis.get('sleep_analysis', ''),
                'ai_vitals_analysis': ai_analysis.get('vitals_analysis', ''),
                'ai_medication_insights': ai_analysis.get('medication_insights', ''),
                'ai_side_effect_correlations': ai_analysis.get('side_effect_correlations', ''),
                'ai_doctor_summary': ai_analysis.get('doctor_summary', ''),
                'ai_patient_summary': ai_analysis.get('patient_summary', ''),
                # Meta
                'conversation_count': observations.get('total_count', 0),
            }
        )

        return report
