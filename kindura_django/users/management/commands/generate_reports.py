"""
Management command to generate patient reports.
Run via cron job for automated daily/weekly/monthly report generation.

Usage:
    python manage.py generate_reports --type daily
    python manage.py generate_reports --type weekly
    python manage.py generate_reports --type monthly
    python manage.py generate_reports --type all
"""

from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import date, timedelta
import openai
import os

from users.models import User, PatientReport, PatientObservation
from medicines.models import Medicine, MedicationEvent


class Command(BaseCommand):
    help = 'Generate patient reports (daily/weekly/monthly)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--type',
            type=str,
            default='daily',
            choices=['daily', 'weekly', 'monthly', 'all'],
            help='Type of report to generate'
        )
        parser.add_argument(
            '--user',
            type=int,
            default=None,
            help='Generate report for specific user ID only'
        )

    def handle(self, *args, **options):
        report_type = options['type']
        user_id = options['user']

        self.stdout.write(f"🔄 Generating {report_type} reports...")

        # Get users to generate reports for
        if user_id:
            users = User.objects.filter(id=user_id)
        else:
            # Get users who have been active (have observations or medications)
            users = User.objects.filter(
                is_active=True
            ).distinct()

        if report_type == 'all':
            report_types = ['daily', 'weekly', 'monthly']
        else:
            report_types = [report_type]

        total_generated = 0

        for user in users:
            for rtype in report_types:
                try:
                    result = self.generate_report_for_user(user, rtype)
                    if result:
                        total_generated += 1
                        self.stdout.write(f"  ✅ {rtype} report for {user.email}")
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(f"  ❌ Error for {user.email}: {e}")
                    )

        self.stdout.write(
            self.style.SUCCESS(f"\n📊 Generated {total_generated} reports")
        )

    def generate_report_for_user(self, user, report_type):
        """Generate a report for a specific user"""
        today = date.today()

        # Determine period
        if report_type == 'daily':
            period_start = today
            period_end = today
            report_date = today
        elif report_type == 'weekly':
            # Only generate on Sunday
            if today.weekday() != 6 and not self.is_forced():
                return None
            period_start = today - timedelta(days=today.weekday())
            period_end = period_start + timedelta(days=6)
            report_date = period_end
        else:  # monthly
            # Only generate on 1st of month
            if today.day != 1 and not self.is_forced():
                return None
            # Previous month
            period_end = today - timedelta(days=1)
            period_start = period_end.replace(day=1)
            report_date = period_end

        # Check if report already exists for today
        existing = PatientReport.objects.filter(
            user=user,
            report_type=report_type,
            report_date=report_date
        ).first()

        if existing and existing.is_finalized:
            return None  # Don't regenerate finalized reports

        # Collect observations
        observations = PatientObservation.objects.filter(
            user=user,
            observed_at__date__gte=period_start,
            observed_at__date__lte=period_end
        ).order_by('observed_at')

        # Collect medication events
        med_events = MedicationEvent.objects.filter(
            medication__user=user,
            scheduled_at__date__gte=period_start,
            scheduled_at__date__lte=period_end
        )

        # Get medications
        medications = Medicine.objects.filter(user=user, is_active=True)

        # Calculate adherence
        total_doses = med_events.count()
        taken_doses = med_events.filter(status='taken').count()
        missed_doses = med_events.filter(status='missed').count()
        late_doses = med_events.filter(status='late').count()
        adherence_pct = (taken_doses / total_doses * 100) if total_doses > 0 else 100

        # Prepare observation summary
        obs_summary = []
        for obs in observations:
            obs_summary.append({
                'type': obs.observation_type,
                'severity': obs.severity,
                'title': obs.title,
                'description': obs.description,
                'value': obs.value,
                'requires_attention': obs.requires_attention,
                'date': obs.observed_at.strftime('%Y-%m-%d %H:%M')
            })

        med_list = [f"{m.drug_name} {m.strength}{m.strength_unit}" for m in medications]

        # Generate AI analysis
        ai_summary, ai_observations, ai_recommendations, ai_concerns = self.generate_ai_analysis(
            report_type, med_list, total_doses, taken_doses, missed_doses, adherence_pct, obs_summary
        )

        # Collect side effects
        side_effects = [
            {'type': obs.observation_type, 'description': obs.description, 'severity': obs.severity}
            for obs in observations if obs.observation_type == 'side_effect'
        ]

        # Create or update report
        report, created = PatientReport.objects.update_or_create(
            user=user,
            report_type=report_type,
            report_date=report_date,
            defaults={
                'period_start': period_start,
                'period_end': period_end,
                'total_doses_scheduled': total_doses,
                'doses_taken': taken_doses,
                'doses_missed': missed_doses,
                'doses_late': late_doses,
                'adherence_percentage': adherence_pct,
                'side_effects_reported': side_effects,
                'side_effects_count': len(side_effects),
                'ai_summary': ai_summary,
                'ai_observations': ai_observations,
                'ai_recommendations': ai_recommendations,
                'ai_concerns': ai_concerns,
                'conversation_count': observations.count(),
            }
        )

        return report

    def generate_ai_analysis(self, report_type, med_list, total_doses, taken_doses,
                             missed_doses, adherence_pct, obs_summary):
        """Generate AI analysis using OpenAI"""
        try:
            openai.api_key = os.getenv('OPENAI_API_KEY')

            prompt = f"""Analyze this patient health data and create a {report_type} medical report for the patient's doctor.

Patient Medications: {', '.join(med_list) if med_list else 'None'}

Medication Adherence ({report_type}):
- Total scheduled doses: {total_doses}
- Doses taken: {taken_doses}
- Doses missed: {missed_doses}
- Adherence rate: {adherence_pct:.1f}%

Patient Observations:
{obs_summary}

Create a structured report with:
1. SUMMARY: Brief overview of patient's health status this {report_type} period
2. KEY_OBSERVATIONS: Important health observations (sleep, mood, symptoms, side effects)
3. CONCERNS: Any concerning patterns or issues requiring doctor attention
4. RECOMMENDATIONS: Suggested actions for the doctor to consider

Focus on actionable insights that help the doctor make informed decisions. Be concise but thorough.
Format each section clearly."""

            response = openai.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a medical AI assistant creating reports for doctors. Be professional, precise, and focus on clinically relevant information."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=1500
            )

            ai_response = response.choices[0].message.content

            # Parse sections
            ai_summary = ""
            ai_observations = ""
            ai_recommendations = ""
            ai_concerns = ""

            current_section = ""
            for line in ai_response.split('\n'):
                if 'SUMMARY' in line.upper():
                    current_section = 'summary'
                elif 'KEY_OBSERVATIONS' in line.upper() or 'OBSERVATIONS' in line.upper():
                    current_section = 'observations'
                elif 'CONCERNS' in line.upper():
                    current_section = 'concerns'
                elif 'RECOMMENDATIONS' in line.upper():
                    current_section = 'recommendations'
                else:
                    if current_section == 'summary':
                        ai_summary += line + '\n'
                    elif current_section == 'observations':
                        ai_observations += line + '\n'
                    elif current_section == 'concerns':
                        ai_concerns += line + '\n'
                    elif current_section == 'recommendations':
                        ai_recommendations += line + '\n'

            return ai_summary.strip(), ai_observations.strip(), ai_recommendations.strip(), ai_concerns.strip()

        except Exception as e:
            self.stdout.write(self.style.WARNING(f"    OpenAI error: {e}"))
            return (
                f"Report for period",
                f"Total observations: {len(obs_summary)}",
                "Please review patient data manually.",
                ""
            )

    def is_forced(self):
        """Check if running with force flag (for testing)"""
        return True  # Always generate for now
