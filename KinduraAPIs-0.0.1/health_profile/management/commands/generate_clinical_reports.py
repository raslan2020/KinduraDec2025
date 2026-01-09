"""
Clinical Report Generation Management Command
==============================================
Following Reports.md Specification for Parkinson's Disease Monitoring

Generates:
- Daily Clinical Summaries (at end of day)
- Weekly Clinical Trend Reports (at end of week)
- Monthly Neurologist Reports (at end of month)

Usage:
    python manage.py generate_clinical_reports --type daily
    python manage.py generate_clinical_reports --type weekly
    python manage.py generate_clinical_reports --type monthly
    python manage.py generate_clinical_reports --type all
    python manage.py generate_clinical_reports --user_id 123 --type daily
"""

import json
import time
from datetime import date, datetime, timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.db.models import Avg, Count, Max, Min
from health_profile.models import (
    MotorSymptomEntry, NonMotorSymptomEntry, MedicationDoseEntry,
    SafetyEvent, SpeechMetrics, CognitiveScreening, ClinicalReport,
    WatchVitals, PatientClinicalProfile
)
from users.models import User


class Command(BaseCommand):
    help = 'Generate clinical reports (daily, weekly, monthly) following Reports.md'

    def add_arguments(self, parser):
        parser.add_argument(
            '--type',
            type=str,
            default='daily',
            choices=['daily', 'weekly', 'monthly', 'all'],
            help='Type of report to generate'
        )
        parser.add_argument(
            '--user_id',
            type=int,
            help='Generate report for specific user (optional)'
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='Force regeneration even if report exists'
        )

    def handle(self, *args, **options):
        report_type = options['type']
        user_id = options.get('user_id')
        force = options.get('force', False)

        self.stdout.write(f"Generating {report_type} reports...")

        # Get users to process
        if user_id:
            users = User.objects.filter(id=user_id)
        else:
            # Get users with clinical profiles or motor symptom data
            users = User.objects.filter(
                motor_symptoms__isnull=False
            ).distinct()

        user_count = users.count()
        self.stdout.write(f"Processing {user_count} users...")

        for user in users:
            try:
                if report_type == 'all':
                    self.generate_daily_report(user, force)
                    self.generate_weekly_report(user, force)
                    self.generate_monthly_report(user, force)
                elif report_type == 'daily':
                    self.generate_daily_report(user, force)
                elif report_type == 'weekly':
                    self.generate_weekly_report(user, force)
                elif report_type == 'monthly':
                    self.generate_monthly_report(user, force)
            except Exception as e:
                self.stderr.write(f"Error processing user {user.id}: {e}")

        self.stdout.write(self.style.SUCCESS(f"Report generation complete"))

    def generate_daily_report(self, user, force=False):
        """Generate Daily Clinical Summary (Reports.md Section 2.2)"""
        today = date.today()
        yesterday = today - timedelta(days=1)

        # Check if report already exists
        existing = ClinicalReport.objects.filter(
            user=user,
            report_type='daily',
            period_start=yesterday,
            period_end=yesterday
        ).first()

        if existing and not force:
            self.stdout.write(f"  Daily report for {user.email} already exists, skipping...")
            return

        start_time = time.time()

        # Get motor symptoms for the day
        motor_entry = MotorSymptomEntry.objects.filter(
            user=user,
            recorded_date=yesterday
        ).first()

        # Get medication doses
        doses = MedicationDoseEntry.objects.filter(
            user=user,
            scheduled_time__date=yesterday
        )

        # Get safety events
        safety_events = SafetyEvent.objects.filter(
            user=user,
            occurred_at__date=yesterday
        )

        # Get watch vitals
        vitals = WatchVitals.objects.filter(
            user=user,
            recorded_at__date=yesterday
        ).order_by('-recorded_at').first()

        # Calculate completeness (per Reports.md Section 6)
        required_fields = 5  # bradykinesia, tremor, rigidity, gait, laterality
        completed_fields = 0
        if motor_entry:
            if motor_entry.bradykinesia:
                completed_fields += 1
            if motor_entry.tremor:
                completed_fields += 1
            if motor_entry.rigidity:
                completed_fields += 1
            if motor_entry.gait_difficulty:
                completed_fields += 1
            if motor_entry.laterality:
                completed_fields += 1

        completeness = (completed_fields / required_fields) * 100 if required_fields > 0 else 0
        meets_criteria = completeness >= 60  # Daily requires >= 60%

        # Build report content (Toon format)
        report_content = {
            "dt": yesterday.isoformat(),
            "motor": {
                "brady": motor_entry.bradykinesia if motor_entry else None,
                "tremor": motor_entry.tremor if motor_entry else None,
                "rigid": motor_entry.rigidity if motor_entry else None,
                "gait": motor_entry.gait_difficulty if motor_entry else None,
                "lat": motor_entry.laterality if motor_entry else None,
                "src": motor_entry.data_source if motor_entry else None,
            } if motor_entry else None,
            "meds": {
                "total": doses.count(),
                "taken": doses.filter(status='taken').count(),
                "missed": doses.filter(status='missed').count(),
                "late": doses.filter(status='late').count(),
            },
            "safety": [
                {"type": e.event_type, "sev": e.severity}
                for e in safety_events
            ],
            "vitals": {
                "hr": vitals.heart_rate if vitals else None,
                "o2": vitals.blood_oxygen if vitals else None,
                "steps": vitals.step_count if vitals else None,
            } if vitals else None,
        }

        # Generate summaries
        motor_summary = self._generate_motor_summary([motor_entry] if motor_entry else [])
        medication_summary = self._generate_medication_summary(doses)
        safety_summary = self._generate_safety_summary(safety_events)

        # Validation checklist (Reports.md Section 8)
        bradykinesia_assessed = motor_entry and motor_entry.bradykinesia is not None
        laterality_captured = motor_entry and motor_entry.laterality is not None
        medication_timing_correlated = doses.exists()
        red_flags_escalated = not safety_events.filter(
            severity__in=['high', 'critical'],
            escalated_to_provider=False
        ).exists()
        data_sources_tagged = motor_entry and motor_entry.data_source is not None

        # Create or update report
        report, created = ClinicalReport.objects.update_or_create(
            user=user,
            report_type='daily',
            period_start=yesterday,
            period_end=yesterday,
            defaults={
                'status': 'complete' if meets_criteria else 'incomplete',
                'data_completeness_percent': completeness,
                'meets_minimum_criteria': meets_criteria,
                'report_content': report_content,
                'motor_summary': motor_summary,
                'medication_summary': medication_summary,
                'safety_summary': safety_summary,
                'bradykinesia_assessed': bradykinesia_assessed,
                'laterality_captured': laterality_captured,
                'medication_timing_correlated': medication_timing_correlated,
                'red_flags_escalated': red_flags_escalated,
                'data_sources_tagged': data_sources_tagged,
                'generation_time_seconds': time.time() - start_time,
            }
        )

        self.stdout.write(f"  Generated daily report for {user.email} ({completeness:.0f}% complete)")

    def generate_weekly_report(self, user, force=False):
        """Generate Weekly Clinical Trend Report (Reports.md Section 2.3)"""
        today = date.today()
        week_start = today - timedelta(days=7)
        week_end = today - timedelta(days=1)

        # Check if report already exists
        existing = ClinicalReport.objects.filter(
            user=user,
            report_type='weekly',
            period_start=week_start,
            period_end=week_end
        ).first()

        if existing and not force:
            self.stdout.write(f"  Weekly report for {user.email} already exists, skipping...")
            return

        start_time = time.time()

        # Get motor symptoms for the week
        motor_entries = MotorSymptomEntry.objects.filter(
            user=user,
            recorded_date__gte=week_start,
            recorded_date__lte=week_end
        ).order_by('recorded_date')

        # Get non-motor symptoms
        non_motor_entries = NonMotorSymptomEntry.objects.filter(
            user=user,
            recorded_date__gte=week_start,
            recorded_date__lte=week_end
        )

        # Get medication doses
        doses = MedicationDoseEntry.objects.filter(
            user=user,
            scheduled_time__date__gte=week_start,
            scheduled_time__date__lte=week_end
        )

        # Get safety events
        safety_events = SafetyEvent.objects.filter(
            user=user,
            occurred_at__date__gte=week_start,
            occurred_at__date__lte=week_end
        )

        # Calculate completeness (at least 4 days of data per Reports.md Section 6)
        days_with_data = motor_entries.count()
        meets_criteria = days_with_data >= 4

        # Calculate averages
        avg_stats = motor_entries.aggregate(
            avg_brady=Avg('bradykinesia'),
            avg_tremor=Avg('tremor'),
            avg_rigidity=Avg('rigidity'),
            avg_gait=Avg('gait_difficulty'),
        )

        # Build report content (Toon format)
        report_content = {
            "period": {"start": week_start.isoformat(), "end": week_end.isoformat()},
            "days": days_with_data,
            "motor_avg": {
                "brady": round(avg_stats['avg_brady'], 1) if avg_stats['avg_brady'] else None,
                "tremor": round(avg_stats['avg_tremor'], 1) if avg_stats['avg_tremor'] else None,
                "rigid": round(avg_stats['avg_rigidity'], 1) if avg_stats['avg_rigidity'] else None,
                "gait": round(avg_stats['avg_gait'], 1) if avg_stats['avg_gait'] else None,
            },
            "motor_trend": [
                {
                    "dt": e.recorded_date.isoformat(),
                    "brady": e.bradykinesia,
                    "tremor": e.tremor,
                    "rigid": e.rigidity,
                    "gait": e.gait_difficulty,
                }
                for e in motor_entries
            ],
            "non_motor": {
                "sleep": non_motor_entries.aggregate(Avg('sleep_disturbance'))['sleep_disturbance__avg'],
                "mood": non_motor_entries.aggregate(Avg('mood_apathy'))['mood_apathy__avg'],
                "fatigue": non_motor_entries.aggregate(Avg('fatigue'))['fatigue__avg'],
            },
            "meds": {
                "total": doses.count(),
                "adherence": round((doses.filter(status='taken').count() / doses.count() * 100), 1) if doses.count() > 0 else None,
            },
            "safety_count": safety_events.count(),
        }

        completeness = (days_with_data / 7) * 100

        # Generate summaries
        motor_summary = self._generate_motor_summary(motor_entries)
        non_motor_summary = self._generate_non_motor_summary(non_motor_entries)
        medication_summary = self._generate_medication_summary(doses)
        safety_summary = self._generate_safety_summary(safety_events)

        # Identify red flags
        red_flags = []
        if avg_stats['avg_brady'] and avg_stats['avg_brady'] >= 4:
            red_flags.append("Severe bradykinesia trend")
        if safety_events.filter(event_type='fall').count() >= 2:
            red_flags.append("Multiple falls this week")
        if doses.filter(status='missed').count() > doses.count() * 0.3:
            red_flags.append("High medication non-adherence")

        # Create or update report
        report, created = ClinicalReport.objects.update_or_create(
            user=user,
            report_type='weekly',
            period_start=week_start,
            period_end=week_end,
            defaults={
                'status': 'complete' if meets_criteria else 'incomplete',
                'data_completeness_percent': completeness,
                'meets_minimum_criteria': meets_criteria,
                'report_content': report_content,
                'motor_summary': motor_summary,
                'non_motor_summary': non_motor_summary,
                'medication_summary': medication_summary,
                'safety_summary': safety_summary,
                'red_flags': red_flags,
                'bradykinesia_assessed': motor_entries.filter(bradykinesia__isnull=False).exists(),
                'laterality_captured': motor_entries.filter(laterality__isnull=False).exists(),
                'generation_time_seconds': time.time() - start_time,
            }
        )

        self.stdout.write(f"  Generated weekly report for {user.email} ({days_with_data} days of data)")

    def generate_monthly_report(self, user, force=False):
        """Generate Monthly Neurologist Report (Reports.md Section 2.4)"""
        today = date.today()
        month_start = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
        month_end = today.replace(day=1) - timedelta(days=1)

        # Check if report already exists
        existing = ClinicalReport.objects.filter(
            user=user,
            report_type='monthly',
            period_start=month_start,
            period_end=month_end
        ).first()

        if existing and not force:
            self.stdout.write(f"  Monthly report for {user.email} already exists, skipping...")
            return

        start_time = time.time()

        # Get all data for the month
        motor_entries = MotorSymptomEntry.objects.filter(
            user=user,
            recorded_date__gte=month_start,
            recorded_date__lte=month_end
        ).order_by('recorded_date')

        non_motor_entries = NonMotorSymptomEntry.objects.filter(
            user=user,
            recorded_date__gte=month_start,
            recorded_date__lte=month_end
        )

        doses = MedicationDoseEntry.objects.filter(
            user=user,
            scheduled_time__date__gte=month_start,
            scheduled_time__date__lte=month_end
        )

        safety_events = SafetyEvent.objects.filter(
            user=user,
            occurred_at__date__gte=month_start,
            occurred_at__date__lte=month_end
        )

        cognitive = CognitiveScreening.objects.filter(
            user=user,
            recorded_date__gte=month_start,
            recorded_date__lte=month_end
        ).order_by('-recorded_date').first()

        speech = SpeechMetrics.objects.filter(
            user=user,
            recorded_date__gte=month_start,
            recorded_date__lte=month_end
        )

        # Calculate completeness (>= 70% per Reports.md Section 6)
        total_days = (month_end - month_start).days + 1
        days_with_motor = motor_entries.count()
        completeness = (days_with_motor / total_days) * 100 if total_days > 0 else 0
        meets_criteria = completeness >= 70

        # Calculate comprehensive statistics
        motor_stats = motor_entries.aggregate(
            avg_brady=Avg('bradykinesia'),
            max_brady=Max('bradykinesia'),
            min_brady=Min('bradykinesia'),
            avg_tremor=Avg('tremor'),
            avg_rigidity=Avg('rigidity'),
            avg_gait=Avg('gait_difficulty'),
            total_freezing=Count('freezing_episodes'),
            total_falls=Count('falls_today'),
        )

        # Build comprehensive report content
        report_content = {
            "period": {"start": month_start.isoformat(), "end": month_end.isoformat()},
            "days_recorded": days_with_motor,
            "completeness": round(completeness, 1),
            "motor": {
                "brady": {
                    "avg": round(motor_stats['avg_brady'], 1) if motor_stats['avg_brady'] else None,
                    "max": motor_stats['max_brady'],
                    "min": motor_stats['min_brady'],
                },
                "tremor_avg": round(motor_stats['avg_tremor'], 1) if motor_stats['avg_tremor'] else None,
                "rigidity_avg": round(motor_stats['avg_rigidity'], 1) if motor_stats['avg_rigidity'] else None,
                "gait_avg": round(motor_stats['avg_gait'], 1) if motor_stats['avg_gait'] else None,
                "freezing_total": motor_stats['total_freezing'],
                "falls_total": motor_stats['total_falls'],
            },
            "non_motor": {
                "sleep_avg": round(non_motor_entries.aggregate(Avg('sleep_disturbance'))['sleep_disturbance__avg'] or 0, 1),
                "mood_avg": round(non_motor_entries.aggregate(Avg('mood_apathy'))['mood_apathy__avg'] or 0, 1),
                "fatigue_avg": round(non_motor_entries.aggregate(Avg('fatigue'))['fatigue__avg'] or 0, 1),
            },
            "medication": {
                "total_doses": doses.count(),
                "taken": doses.filter(status='taken').count(),
                "missed": doses.filter(status='missed').count(),
                "late": doses.filter(status='late').count(),
                "adherence_pct": round((doses.filter(status='taken').count() / doses.count() * 100), 1) if doses.count() > 0 else None,
            },
            "safety": {
                "falls": safety_events.filter(event_type='fall').count(),
                "hallucinations": safety_events.filter(event_type='hallucination').count(),
                "critical_events": safety_events.filter(severity='critical').count(),
            },
            "cognitive": {
                "moca": cognitive.moca_lite_score if cognitive else None,
                "phq9": cognitive.phq9_total_score if cognitive else None,
                "phq9_q9": cognitive.phq9_q9_score if cognitive else None,
            } if cognitive else None,
        }

        # Generate summaries
        motor_summary = self._generate_motor_summary(motor_entries)
        non_motor_summary = self._generate_non_motor_summary(non_motor_entries)
        medication_summary = self._generate_medication_summary(doses)
        safety_summary = self._generate_safety_summary(safety_events)
        qol_summary = self._generate_qol_summary(non_motor_entries, cognitive)

        # Generate AI insights and recommendations
        ai_insights = self._generate_insights(report_content)
        red_flags = self._identify_red_flags(report_content, safety_events, cognitive)
        recommendations = self._generate_recommendations(report_content, red_flags)

        # Create or update report
        report, created = ClinicalReport.objects.update_or_create(
            user=user,
            report_type='monthly',
            period_start=month_start,
            period_end=month_end,
            defaults={
                'status': 'complete' if meets_criteria else 'incomplete',
                'data_completeness_percent': completeness,
                'meets_minimum_criteria': meets_criteria,
                'report_content': report_content,
                'motor_summary': motor_summary,
                'non_motor_summary': non_motor_summary,
                'medication_summary': medication_summary,
                'safety_summary': safety_summary,
                'quality_of_life_summary': qol_summary,
                'ai_insights': ai_insights,
                'red_flags': red_flags,
                'recommendations': recommendations,
                'bradykinesia_assessed': motor_entries.filter(bradykinesia__isnull=False).exists(),
                'laterality_captured': motor_entries.filter(laterality__isnull=False).exists(),
                'generation_time_seconds': time.time() - start_time,
            }
        )

        self.stdout.write(f"  Generated monthly report for {user.email} ({completeness:.0f}% complete)")

    def _generate_motor_summary(self, entries):
        """Generate motor symptom summary text"""
        if not entries:
            return "No motor symptom data recorded for this period."

        entries_list = list(entries)
        if not entries_list:
            return "No motor symptom data recorded for this period."

        avg_brady = sum(e.bradykinesia or 0 for e in entries_list) / len(entries_list)
        avg_tremor = sum(e.tremor or 0 for e in entries_list) / len(entries_list)

        summary = f"Recorded {len(entries_list)} days of motor symptoms. "
        summary += f"Average bradykinesia: {avg_brady:.1f}/5. "
        summary += f"Average tremor: {avg_tremor:.1f}/5."

        return summary

    def _generate_non_motor_summary(self, entries):
        """Generate non-motor symptom summary text"""
        if not entries.exists():
            return "No non-motor symptom data recorded for this period."

        count = entries.count()
        summary = f"Recorded {count} non-motor assessments. "

        sleep_avg = entries.aggregate(Avg('sleep_disturbance'))['sleep_disturbance__avg']
        if sleep_avg:
            summary += f"Average sleep issues: {sleep_avg:.1f}/5. "

        return summary

    def _generate_medication_summary(self, doses):
        """Generate medication adherence summary"""
        if not doses.exists():
            return "No medication dose data recorded for this period."

        total = doses.count()
        taken = doses.filter(status='taken').count()
        missed = doses.filter(status='missed').count()
        adherence = (taken / total * 100) if total > 0 else 0

        summary = f"Medication adherence: {adherence:.0f}% ({taken}/{total} doses taken). "
        if missed > 0:
            summary += f"{missed} doses missed."

        return summary

    def _generate_safety_summary(self, events):
        """Generate safety events summary"""
        if not events.exists():
            return "No safety events recorded for this period."

        falls = events.filter(event_type='fall').count()
        hallucinations = events.filter(event_type='hallucination').count()
        critical = events.filter(severity='critical').count()

        summary = f"Total safety events: {events.count()}. "
        if falls > 0:
            summary += f"Falls: {falls}. "
        if hallucinations > 0:
            summary += f"Hallucinations: {hallucinations}. "
        if critical > 0:
            summary += f"Critical events requiring attention: {critical}."

        return summary

    def _generate_qol_summary(self, non_motor, cognitive):
        """Generate quality of life summary"""
        summary = "Quality of life assessment: "

        if non_motor.exists():
            mood_avg = non_motor.aggregate(Avg('mood_apathy'))['mood_apathy__avg']
            fatigue_avg = non_motor.aggregate(Avg('fatigue'))['fatigue__avg']

            if mood_avg and mood_avg >= 3:
                summary += "Mood concerns noted. "
            if fatigue_avg and fatigue_avg >= 3:
                summary += "Significant fatigue reported. "

        if cognitive:
            if cognitive.phq9_total_score and cognitive.phq9_total_score >= 10:
                summary += "PHQ-9 indicates moderate depression symptoms. "
            if cognitive.moca_lite_score and cognitive.moca_lite_score < 22:
                summary += "MoCA-lite suggests cognitive concerns. "

        if summary == "Quality of life assessment: ":
            summary += "No significant QoL concerns identified."

        return summary

    def _generate_insights(self, report_content):
        """Generate AI insights based on report data"""
        insights = []

        motor = report_content.get('motor', {})
        if motor.get('brady', {}).get('avg') and motor['brady']['avg'] >= 3.5:
            insights.append({
                "type": "trend",
                "severity": "warning",
                "text": "Bradykinesia trending higher than typical. Consider medication timing review."
            })

        meds = report_content.get('medication', {})
        if meds.get('adherence_pct') and meds['adherence_pct'] < 80:
            insights.append({
                "type": "adherence",
                "severity": "warning",
                "text": f"Medication adherence at {meds['adherence_pct']}%. Discuss barriers with patient."
            })

        return insights

    def _identify_red_flags(self, report_content, safety_events, cognitive):
        """Identify red flags per Reports.md Section 3.8"""
        red_flags = []

        # Check for falls
        falls_count = safety_events.filter(event_type='fall').count()
        if falls_count >= 2:
            red_flags.append(f"Multiple falls ({falls_count}) - fall risk assessment recommended")

        # Check for hallucinations
        if safety_events.filter(event_type='hallucination').exists():
            red_flags.append("Hallucinations reported - medication review advised")

        # Check PHQ-9 Q9 (suicidal ideation)
        if cognitive and cognitive.phq9_q9_score and cognitive.phq9_q9_score >= 2:
            red_flags.append("PHQ-9 Q9 >= 2 - URGENT mental health assessment required")

        # Check for bradykinesia not assessed (per Reports.md)
        motor = report_content.get('motor', {})
        if not motor.get('brady', {}).get('avg'):
            red_flags.append("Core diagnostic feature (bradykinesia) not consistently assessed")

        return red_flags

    def _generate_recommendations(self, report_content, red_flags):
        """Generate recommendations for clinician"""
        recommendations = []

        if red_flags:
            recommendations.append("Review identified red flags before next appointment")

        motor = report_content.get('motor', {})
        if motor.get('freezing_total', 0) > 5:
            recommendations.append("Consider PT referral for freezing episodes")

        meds = report_content.get('medication', {})
        if meds.get('late', 0) > meds.get('total_doses', 1) * 0.2:
            recommendations.append("Many late doses - review medication timing schedule")

        if report_content.get('completeness', 0) < 50:
            recommendations.append("Low data completeness - patient may need support with daily logging")

        return recommendations
