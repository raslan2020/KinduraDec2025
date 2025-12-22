"""
Insight Generation Service
Generates AI-powered health insights based on biomarker data.
Includes user-specific analysis and research references.
"""
import logging
import json
from typing import List, Dict, Optional, Any
from decimal import Decimal
from datetime import datetime, timedelta
from django.utils import timezone

from .models import HealthInsight, Biomarker, UploadedMedicalReport
from .biomarker_service import BiomarkerService
from llm_model.gpt_model import GPTModel

logger = logging.getLogger(__name__)

# Current prompt version for tracking
PROMPT_VERSION = "v2"


class InsightGenerationService:
    """
    Service for generating AI-powered health insights.
    Analyzes biomarkers in context of user's medications, history, and latest research.
    """

    # Biomarkers that typically warrant insights when abnormal
    PRIORITY_BIOMARKERS = [
        'glucose', 'fasting glucose', 'hemoglobin a1c', 'hba1c',
        'ldl cholesterol', 'hdl cholesterol', 'total cholesterol', 'triglycerides',
        'creatinine', 'egfr', 'bun',
        'alt', 'ast', 'alkaline phosphatase',
        'tsh', 't3', 't4',
        'hemoglobin', 'hematocrit', 'white blood cell count', 'platelets',
        'vitamin d', 'vitamin b12', 'ferritin', 'iron',
        'potassium', 'sodium', 'calcium',
        'psa', 'crp', 'esr',
    ]

    @staticmethod
    def convert_decimals(obj: Any) -> Any:
        """Recursively convert Decimal values to float for JSON serialization"""
        if isinstance(obj, Decimal):
            return float(obj)
        elif isinstance(obj, dict):
            return {k: InsightGenerationService.convert_decimals(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [InsightGenerationService.convert_decimals(item) for item in obj]
        return obj

    @classmethod
    def generate_insights_for_report(
        cls,
        user,
        report: UploadedMedicalReport,
        biomarkers: List[Biomarker]
    ) -> List[HealthInsight]:
        """
        Generate AI insights for all biomarkers from a newly uploaded report.

        Args:
            user: The user who uploaded the report
            report: The UploadedMedicalReport instance
            biomarkers: List of Biomarker instances extracted from the report

        Returns:
            List of created HealthInsight instances
        """
        if not biomarkers:
            logger.info(f"No biomarkers to generate insights for report {report.id}")
            return []

        insights_created = []

        # Get user context once (medications, other biomarkers, history)
        user_context = cls._get_user_context(user)

        # Filter to abnormal or priority biomarkers
        biomarkers_to_analyze = []
        for biomarker in biomarkers:
            status = cls._calculate_status(biomarker)
            is_abnormal = status not in ['normal', None]
            is_priority = biomarker.name.lower() in cls.PRIORITY_BIOMARKERS

            if is_abnormal or is_priority:
                biomarkers_to_analyze.append((biomarker, status))

        if not biomarkers_to_analyze:
            logger.info(f"No abnormal/priority biomarkers for report {report.id}")
            # Still generate a summary insight for normal results
            cls._generate_normal_results_insight(user, report)
            return []

        # Generate insights in batches to reduce API calls
        # Group similar biomarkers together
        batch_size = 5
        for i in range(0, len(biomarkers_to_analyze), batch_size):
            batch = biomarkers_to_analyze[i:i + batch_size]

            try:
                batch_insights = cls._generate_batch_insights(
                    user=user,
                    report=report,
                    biomarkers_with_status=batch,
                    user_context=user_context
                )
                insights_created.extend(batch_insights)
            except Exception as e:
                logger.error(f"Error generating batch insights: {e}")
                # Fall back to individual generation
                for biomarker, status in batch:
                    try:
                        insight = cls._generate_single_insight(
                            user=user,
                            report=report,
                            biomarker=biomarker,
                            status=status,
                            user_context=user_context
                        )
                        if insight:
                            insights_created.append(insight)
                    except Exception as inner_e:
                        logger.error(f"Error generating insight for {biomarker.name}: {inner_e}")

        logger.info(f"Generated {len(insights_created)} insights for report {report.id}")
        return insights_created

    @classmethod
    def _get_user_context(cls, user) -> Dict:
        """Get user's medications, recent biomarkers, and health history for context"""
        from medicines.models import Medicine

        context = {
            'medications': [],
            'other_biomarkers': [],
            'health_conditions': [],
            'recent_observations': [],
        }

        # Get active medications
        try:
            medications = Medicine.objects.filter(user=user, is_active=True)
            context['medications'] = [
                {
                    'name': med.drug_name,
                    'strength': float(med.strength) if med.strength else None,
                    'unit': med.strength_unit,
                    'form': med.form,
                    'frequency': med.schedule.get('frequency') if med.schedule else None,
                }
                for med in medications
            ]
        except Exception as e:
            logger.warning(f"Could not fetch medications: {e}")

        # Get other recent biomarkers (last 90 days)
        try:
            ninety_days_ago = timezone.now().date() - timedelta(days=90)
            recent_biomarkers = Biomarker.objects.filter(
                user=user,
                test_date__gte=ninety_days_ago
            ).order_by('name', '-test_date').distinct('name')[:20]

            context['other_biomarkers'] = [
                {
                    'name': b.name,
                    'value': float(b.value) if b.value else None,
                    'unit': b.unit,
                    'status': cls._calculate_status(b),
                    'test_date': b.test_date.isoformat() if b.test_date else None,
                }
                for b in recent_biomarkers
            ]
        except Exception as e:
            logger.warning(f"Could not fetch other biomarkers: {e}")

        # Get patient observations (symptoms, side effects)
        try:
            from users.models import PatientObservation
            recent_observations = PatientObservation.objects.filter(
                user=user,
                created_at__gte=timezone.now() - timedelta(days=30)
            ).order_by('-created_at')[:10]

            context['recent_observations'] = [
                {
                    'type': obs.observation_type,
                    'description': obs.description,
                    'severity': obs.severity,
                    'date': obs.created_at.isoformat(),
                }
                for obs in recent_observations
            ]
        except Exception as e:
            logger.warning(f"Could not fetch observations: {e}")

        return cls.convert_decimals(context)

    @classmethod
    def _calculate_status(cls, biomarker: Biomarker) -> str:
        """Calculate the status of a biomarker value"""
        if biomarker.value is None:
            return None

        value = float(biomarker.value)
        ref_min = float(biomarker.reference_min) if biomarker.reference_min else None
        ref_max = float(biomarker.reference_max) if biomarker.reference_max else None

        return BiomarkerService.calculate_status(value, ref_min, ref_max)

    @classmethod
    def _generate_batch_insights(
        cls,
        user,
        report: UploadedMedicalReport,
        biomarkers_with_status: List[tuple],
        user_context: Dict
    ) -> List[HealthInsight]:
        """Generate insights for a batch of biomarkers in a single API call"""

        # Prepare biomarker data for the prompt
        biomarker_data = []
        for biomarker, status in biomarkers_with_status:
            # Get historical data for trend
            trend_info = cls._get_trend_info(user, biomarker)

            biomarker_data.append({
                'name': biomarker.name,
                'value': float(biomarker.value) if biomarker.value else None,
                'unit': biomarker.unit,
                'reference_min': float(biomarker.reference_min) if biomarker.reference_min else None,
                'reference_max': float(biomarker.reference_max) if biomarker.reference_max else None,
                'status': status,
                'test_date': biomarker.test_date.isoformat() if biomarker.test_date else None,
                'trend': trend_info,
            })

        # Build the prompt
        prompt = cls._build_insight_prompt(biomarker_data, user_context)

        # Call OpenAI
        try:
            gpt = GPTModel(model="gpt-4o-mini")
            messages = [
                {"role": "system", "content": cls._get_system_prompt()},
                {"role": "user", "content": prompt}
            ]

            response = gpt.chat(messages, temperature=0.3, max_tokens=8000)

            if response:
                insights_data = json.loads(response)
                return cls._create_insight_objects(
                    user=user,
                    report=report,
                    biomarkers_with_status=biomarkers_with_status,
                    insights_data=insights_data,
                    user_context=user_context
                )
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response: {e}")
        except Exception as e:
            logger.error(f"AI insight generation failed: {e}")

        return []

    @classmethod
    def _generate_single_insight(
        cls,
        user,
        report: UploadedMedicalReport,
        biomarker: Biomarker,
        status: str,
        user_context: Dict
    ) -> Optional[HealthInsight]:
        """Generate insight for a single biomarker (fallback method)"""

        trend_info = cls._get_trend_info(user, biomarker)

        biomarker_data = [{
            'name': biomarker.name,
            'value': float(biomarker.value) if biomarker.value else None,
            'unit': biomarker.unit,
            'reference_min': float(biomarker.reference_min) if biomarker.reference_min else None,
            'reference_max': float(biomarker.reference_max) if biomarker.reference_max else None,
            'status': status,
            'test_date': biomarker.test_date.isoformat() if biomarker.test_date else None,
            'trend': trend_info,
        }]

        prompt = cls._build_insight_prompt(biomarker_data, user_context)

        try:
            gpt = GPTModel(model="gpt-4o-mini")
            messages = [
                {"role": "system", "content": cls._get_system_prompt()},
                {"role": "user", "content": prompt}
            ]

            response = gpt.chat(messages, temperature=0.3, max_tokens=4000)

            if response:
                insights_data = json.loads(response)
                insights = cls._create_insight_objects(
                    user=user,
                    report=report,
                    biomarkers_with_status=[(biomarker, status)],
                    insights_data=insights_data,
                    user_context=user_context
                )
                return insights[0] if insights else None
        except Exception as e:
            logger.error(f"Single insight generation failed for {biomarker.name}: {e}")

        return None

    @classmethod
    def _get_trend_info(cls, user, biomarker: Biomarker) -> Dict:
        """Get trend information for a biomarker"""
        try:
            # Get previous observations
            previous_obs = Biomarker.objects.filter(
                user=user,
                name__iexact=biomarker.name,
                test_date__lt=biomarker.test_date
            ).order_by('-test_date')[:5]

            if not previous_obs:
                return {'direction': 'unknown', 'percentage': None, 'previous_value': None}

            previous = previous_obs[0]
            if previous.value and biomarker.value:
                prev_val = float(previous.value)
                curr_val = float(biomarker.value)

                if prev_val != 0:
                    change_pct = ((curr_val - prev_val) / prev_val) * 100

                    if abs(change_pct) < 5:
                        direction = 'stable'
                    elif change_pct > 0:
                        direction = 'increasing'
                    else:
                        direction = 'decreasing'

                    return {
                        'direction': direction,
                        'percentage': round(change_pct, 1),
                        'previous_value': prev_val,
                        'previous_date': previous.test_date.isoformat() if previous.test_date else None,
                    }
        except Exception as e:
            logger.warning(f"Could not calculate trend for {biomarker.name}: {e}")

        return {'direction': 'unknown', 'percentage': None, 'previous_value': None}

    @classmethod
    def _get_system_prompt(cls) -> str:
        """Get the system prompt for the AI"""
        return """You are a medical health analyst AI assistant. Your role is to:
1. Analyze biomarker results in the context of the patient's overall health
2. Provide personalized insights based on the patient's medications and health history
3. Reference current medical research and guidelines transparently
4. Give actionable recommendations while advising doctor consultation for serious concerns

IMPORTANT GUIDELINES:
- Always cite specific research or medical guidelines when making claims
- Be transparent about the source of recommendations (e.g., "According to AHA guidelines...", "Research from NEJM suggests...")
- Consider drug interactions when the patient is on medications
- Provide severity and urgency ratings based on clinical significance
- Never make diagnoses - only provide analysis and suggest doctor consultation
- Use patient-friendly language while being medically accurate

You must respond with valid JSON only."""

    @classmethod
    def _build_insight_prompt(cls, biomarker_data: List[Dict], user_context: Dict) -> str:
        """Build the prompt for insight generation"""

        prompt = f"""Analyze the following biomarker results and generate comprehensive health insights.

BIOMARKER RESULTS:
{json.dumps(biomarker_data, indent=2)}

PATIENT CONTEXT:
- Current Medications: {json.dumps(user_context.get('medications', []))}
- Other Recent Biomarkers: {json.dumps(user_context.get('other_biomarkers', []))}
- Recent Health Observations: {json.dumps(user_context.get('recent_observations', []))}

For EACH biomarker, provide a JSON response with this structure:
{{
    "insights": [
        {{
            "biomarker_name": "exact biomarker name",
            "title": "Clear, descriptive title (e.g., 'Elevated LDL Cholesterol Indicates Cardiovascular Risk')",
            "summary": "2-3 sentence summary for quick reading",
            "detailed_analysis": "Comprehensive analysis including:\\n- What this result means for this specific patient\\n- How it relates to their medications\\n- Correlation with other biomarkers\\n- Clinical significance",
            "severity": "critical|warning|info|success",
            "urgency": "immediate|soon|routine|none",
            "research_references": [
                {{
                    "source": "Name of journal, guideline, or organization",
                    "year": "publication year or 'current guidelines'",
                    "finding": "Specific relevant finding or recommendation",
                    "relevance": "How this applies to the patient"
                }}
            ],
            "research_summary": "Summary of what current research says about this biomarker level",
            "recommendations": [
                {{
                    "action": "Specific actionable recommendation",
                    "priority": "high|medium|low",
                    "timeframe": "When to take action",
                    "rationale": "Why this is recommended based on research"
                }}
            ],
            "doctor_discussion_points": ["Point 1 to discuss with doctor", "Point 2"],
            "lifestyle_tips": ["Lifestyle modification 1", "Lifestyle modification 2"],
            "related_biomarkers": ["Other biomarkers that relate to this"],
            "medication_considerations": ["How current medications may affect this"],
            "requires_doctor_visit": true/false,
            "deviation_info": {{
                "deviation_percent": number or null,
                "is_improving": true/false/null based on trend
            }}
        }}
    ]
}}

Be specific to THIS patient's results and context. Reference real medical research and guidelines."""

        return prompt

    @classmethod
    def _create_insight_objects(
        cls,
        user,
        report: UploadedMedicalReport,
        biomarkers_with_status: List[tuple],
        insights_data: Dict,
        user_context: Dict
    ) -> List[HealthInsight]:
        """Create HealthInsight database objects from AI response"""

        created_insights = []
        insights_list = insights_data.get('insights', [])

        # Create a mapping of biomarker names to objects
        biomarker_map = {b.name.lower(): (b, status) for b, status in biomarkers_with_status}

        for insight_data in insights_list:
            biomarker_name = insight_data.get('biomarker_name', '')
            biomarker_key = biomarker_name.lower()

            # Find matching biomarker
            biomarker, status = biomarker_map.get(biomarker_key, (None, None))

            if not biomarker:
                # Try fuzzy matching
                for key, (b, s) in biomarker_map.items():
                    if key in biomarker_key or biomarker_key in key:
                        biomarker, status = b, s
                        break

            if not biomarker:
                logger.warning(f"Could not match insight to biomarker: {biomarker_name}")
                continue

            try:
                # Calculate deviation
                deviation_info = insight_data.get('deviation_info', {})
                deviation_percent = deviation_info.get('deviation_percent')

                if deviation_percent is None and biomarker.reference_max and biomarker.value:
                    if status == 'high' or status == 'critical_high':
                        deviation_percent = ((float(biomarker.value) - float(biomarker.reference_max)) / float(biomarker.reference_max)) * 100
                    elif status == 'low' or status == 'critical_low':
                        if biomarker.reference_min:
                            deviation_percent = ((float(biomarker.reference_min) - float(biomarker.value)) / float(biomarker.reference_min)) * 100

                # Get trend info
                trend_info = cls._get_trend_info(user, biomarker)

                insight = HealthInsight.objects.create(
                    user=user,
                    report=report,
                    biomarker=biomarker,
                    biomarker_name=biomarker.name,
                    insight_type='biomarker_analysis',
                    title=insight_data.get('title', f'{biomarker.name} Analysis'),
                    summary=insight_data.get('summary', ''),
                    detailed_analysis=insight_data.get('detailed_analysis', ''),
                    user_context=user_context,
                    research_references=insight_data.get('research_references', []),
                    research_summary=insight_data.get('research_summary', ''),
                    biomarker_value=float(biomarker.value) if biomarker.value else None,
                    biomarker_unit=biomarker.unit,
                    reference_min=float(biomarker.reference_min) if biomarker.reference_min else None,
                    reference_max=float(biomarker.reference_max) if biomarker.reference_max else None,
                    status=status,
                    deviation_percent=deviation_percent,
                    trend_direction=trend_info.get('direction'),
                    trend_percentage=trend_info.get('percentage'),
                    previous_value=trend_info.get('previous_value'),
                    severity=insight_data.get('severity', 'info'),
                    urgency=insight_data.get('urgency', 'routine'),
                    recommendations=insight_data.get('recommendations', []),
                    doctor_discussion_points=insight_data.get('doctor_discussion_points', []),
                    lifestyle_tips=insight_data.get('lifestyle_tips', []),
                    related_biomarkers=insight_data.get('related_biomarkers', []),
                    related_medications=insight_data.get('medication_considerations', []),
                    requires_doctor_visit=insight_data.get('requires_doctor_visit', False),
                    ai_model_used='gpt-4o-mini',
                    generation_prompt_version=PROMPT_VERSION,
                )

                created_insights.append(insight)
                logger.info(f"Created insight for {biomarker.name}: {insight.title}")

            except Exception as e:
                logger.error(f"Failed to create insight object for {biomarker_name}: {e}")

        return created_insights

    @classmethod
    def _generate_normal_results_insight(cls, user, report: UploadedMedicalReport):
        """Generate a summary insight when all results are normal"""
        try:
            HealthInsight.objects.create(
                user=user,
                report=report,
                biomarker_name='Overall Results',
                insight_type='biomarker_analysis',
                title='All Lab Results Within Normal Range',
                summary='Great news! All biomarkers from this report are within normal reference ranges.',
                detailed_analysis='Your lab results show all tested biomarkers are within healthy reference ranges. '
                                  'This suggests your body systems are functioning well. Continue maintaining your '
                                  'current healthy lifestyle habits and follow your medication schedule as prescribed.',
                severity='success',
                urgency='none',
                recommendations=[{
                    'action': 'Continue current healthy lifestyle',
                    'priority': 'medium',
                    'timeframe': 'Ongoing',
                    'rationale': 'Maintaining good habits helps sustain healthy biomarker levels'
                }],
                lifestyle_tips=[
                    'Continue balanced nutrition',
                    'Maintain regular physical activity',
                    'Keep up with regular check-ups'
                ],
                requires_doctor_visit=False,
                ai_model_used='system',
                generation_prompt_version=PROMPT_VERSION,
            )
        except Exception as e:
            logger.error(f"Failed to create normal results insight: {e}")

    @classmethod
    def get_user_insights(
        cls,
        user,
        include_dismissed: bool = False,
        severity_filter: Optional[str] = None,
        limit: int = 50
    ) -> List[HealthInsight]:
        """Get insights for a user with optional filters"""

        queryset = HealthInsight.objects.filter(user=user)

        if not include_dismissed:
            queryset = queryset.filter(is_dismissed=False)

        if severity_filter:
            queryset = queryset.filter(severity=severity_filter)

        return list(queryset.order_by('-created_at')[:limit])

    @classmethod
    def get_insights_for_report(cls, report: UploadedMedicalReport) -> List[HealthInsight]:
        """Get all insights generated from a specific report"""
        return list(HealthInsight.objects.filter(report=report).order_by('-severity', '-created_at'))

    @classmethod
    def regenerate_insights_for_report(cls, user, report: UploadedMedicalReport) -> List[HealthInsight]:
        """Regenerate insights for a report (deletes existing and creates new)"""

        # Delete existing insights for this report
        HealthInsight.objects.filter(report=report).delete()

        # Get biomarkers from this report
        biomarkers = list(Biomarker.objects.filter(report=report))

        # Generate new insights
        return cls.generate_insights_for_report(user, report, biomarkers)
