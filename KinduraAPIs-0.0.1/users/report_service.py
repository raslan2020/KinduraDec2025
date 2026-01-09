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
        Generate a comprehensive report with all analytics
        Progress stages:
        - 5%: Started, determining date range
        - 15%: Collecting observations
        - 25%: Collecting medication data
        - 40%: Collecting vitals data
        - 55%: Collecting sleep data
        - 65%: Collecting fall data
        - 75%: Collecting biomarker data
        - 85%: Calculating health scores
        - 95%: Running AI analysis
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
        self._update_progress(15)
        report_data['observations'] = self._collect_observations(period_start, period_end)

        self._update_progress(25)
        report_data['medication_data'] = self._collect_medication_data(period_start, period_end)

        self._update_progress(40)
        report_data['vitals_data'] = self._collect_vitals_data(period_start, period_end)

        self._update_progress(55)
        report_data['sleep_data'] = self._collect_sleep_data(period_start, period_end)

        self._update_progress(65)
        report_data['fall_data'] = self._collect_fall_data(period_start, period_end)

        self._update_progress(75)
        report_data['biomarker_data'] = self._collect_biomarker_data(period_start, period_end)

        # Calculate health scores
        self._update_progress(85)
        report_data['scores'] = self._calculate_health_scores(report_data)

        # Generate AI analysis (this takes the longest)
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
        """Collect vitals data for the period"""
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

        # Daily averages (for trend graph)
        daily_vitals = vitals.annotate(
            day=TruncDate('recorded_at')
        ).values('day').annotate(
            avg_hr=Avg('heart_rate'),
            min_hr=Min('heart_rate'),
            max_hr=Max('heart_rate'),
            avg_spo2=Avg('blood_oxygen'),
            avg_hrv=Avg('hrv'),
        ).order_by('day')

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
            'total_readings': vitals.count(),
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

    def _calculate_health_scores(self, report_data):
        """Calculate health scores based on collected data"""
        scores = {
            'adherence_score': 0,
            'sleep_score': 0,
            'vitals_score': 0,
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

        # Overall score (weighted average)
        scores['overall_score'] = int(
            scores['adherence_score'] * 0.4 +
            scores['sleep_score'] * 0.3 +
            scores['vitals_score'] * 0.3
        )

        return scores

    def _generate_ai_analysis(self, report_data, report_type):
        """Generate comprehensive AI analysis for the report"""
        try:
            # Prepare data summary for AI
            med_data = report_data.get('medication_data', {})
            vitals_data = report_data.get('vitals_data', {})
            sleep_data = report_data.get('sleep_data', {})
            fall_data = report_data.get('fall_data', {})
            biomarker_data = report_data.get('biomarker_data', {})
            observations = report_data.get('observations', {})
            scores = report_data.get('scores', {})

            prompt = f"""Analyze this comprehensive patient health data and create a detailed {report_type} medical report.

=== MEDICATION ADHERENCE ===
- Medications: {', '.join(med_data.get('medications_list', [])) or 'None'}
- Total Scheduled Doses: {med_data.get('total_doses_scheduled', 0)}
- Doses Taken: {med_data.get('doses_taken', 0)}
- Doses Missed: {med_data.get('doses_missed', 0)}
- Doses Late: {med_data.get('doses_late', 0)}
- Adherence Rate: {med_data.get('adherence_percentage', 0):.1f}%
- Side Effects Reported: {json.dumps(med_data.get('side_effects', [])[:10])}
- Per-Medication Performance: {json.dumps({k: {kk: vv for kk, vv in v.items() if kk != 'side_effects'} for k, v in med_data.get('medication_analytics', {}).items()})}

=== VITAL SIGNS ===
- Heart Rate: Avg {vitals_data.get('heart_rate', {}).get('avg', 'N/A')} bpm (Min: {vitals_data.get('heart_rate', {}).get('min', 'N/A')}, Max: {vitals_data.get('heart_rate', {}).get('max', 'N/A')})
- Blood Oxygen (SpO2): Avg {vitals_data.get('blood_oxygen', {}).get('avg', 'N/A')}%
- Heart Rate Variability: Avg {vitals_data.get('hrv', {}).get('avg', 'N/A')} ms
- Total Readings: {vitals_data.get('total_readings', 0)}

=== SLEEP DATA ===
- Average Sleep: {sleep_data.get('avg_hours', 'N/A')} hours
- Sleep Quality Score: {sleep_data.get('avg_quality_score', 'N/A')}/3
- Average Deep Sleep: {sleep_data.get('avg_deep_sleep', 'N/A')} hours
- Average REM Sleep: {sleep_data.get('avg_rem_sleep', 'N/A')} hours
- Average Awakenings: {sleep_data.get('avg_awakenings', 'N/A')}
- Nights Tracked: {sleep_data.get('nights_tracked', 0)}
- Sleep Patterns: {json.dumps(sleep_data.get('patterns', []))}

=== FALL EVENTS ===
- Total Falls: {fall_data.get('total_falls', 0)}
- Fall Events: {json.dumps(fall_data.get('events', [])[:5])}

=== BIOMARKER CHANGES & ABNORMALITIES ===
{json.dumps(biomarker_data.get('biomarkers', {}), indent=2) if biomarker_data.get('has_data') else 'No new lab results during this period'}

CRITICAL ABNORMALITIES (Require Immediate Attention):
{json.dumps(biomarker_data.get('critical_abnormalities', []), indent=2) if biomarker_data.get('critical_count', 0) > 0 else 'None'}

OTHER ABNORMALITIES:
{json.dumps(biomarker_data.get('abnormalities', []), indent=2) if biomarker_data.get('abnormal_count', 0) > 0 else 'All values within normal range'}

=== PATIENT OBSERVATIONS ===
- Total Observations: {observations.get('total_count', 0)}
- Requiring Attention: {observations.get('attention_required', 0)}
- Severe/Critical: {observations.get('severe_count', 0)}
- By Type: {json.dumps({k: len(v) for k, v in observations.get('by_type', {}).items()})}

=== HEALTH SCORES ===
- Overall Score: {scores.get('overall_score', 0)}/100
- Adherence Score: {scores.get('adherence_score', 0)}/100
- Sleep Score: {scores.get('sleep_score', 0)}/100
- Vitals Score: {scores.get('vitals_score', 0)}/100

Please provide a comprehensive analysis in the following JSON format:
{{
    "doctor_summary": "Executive summary for the doctor (3-5 sentences highlighting key concerns and successes)",
    "patient_summary": "Patient-friendly summary (2-3 sentences in simple language)",
    "medication_insights": "Analysis of medication adherence patterns, timing issues, and any concerning side effects",
    "sleep_analysis": "Detailed analysis of sleep patterns, quality, and recommendations",
    "vitals_analysis": "Analysis of heart rate, SpO2, HRV trends and any concerning patterns",
    "side_effect_correlations": "Analysis connecting side effects to specific medications if possible",
    "concerns": ["List of items requiring medical attention"],
    "recommendations": ["List of actionable recommendations for the doctor"],
    "patient_tips": ["List of simple tips for the patient to improve health outcomes"]
}}

Be specific, actionable, and clinically relevant. Focus on patterns and correlations that help the doctor make informed decisions."""

            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a medical AI assistant creating comprehensive health reports for doctors. Be professional, precise, and focus on clinically actionable insights. Always respond in valid JSON format."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=2500,
                temperature=0.3
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
                    'medication_insights': '',
                    'sleep_analysis': '',
                    'vitals_analysis': '',
                    'side_effect_correlations': '',
                    'concerns': [],
                    'recommendations': [],
                    'patient_tips': [],
                }

            return ai_analysis

        except Exception as e:
            logger.error("OpenAI error in report generation: %s", e)
            return {
                'doctor_summary': f"Report for {report_data['period_start']} to {report_data['period_end']}. AI analysis unavailable.",
                'patient_summary': 'Your health data has been collected. Please discuss with your doctor.',
                'medication_insights': f"Adherence rate: {med_data.get('adherence_percentage', 0):.1f}%",
                'sleep_analysis': '',
                'vitals_analysis': '',
                'side_effect_correlations': '',
                'concerns': [],
                'recommendations': ['Please review patient data manually.'],
                'patient_tips': ['Continue taking medications as prescribed.'],
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
