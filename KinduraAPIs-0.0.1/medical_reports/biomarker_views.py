"""
Biomarkers API Views
Comprehensive endpoints for biomarker management and analytics
"""
import logging
import json
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from .biomarker_service import BiomarkerService
from .unit_conversion_service import UnitConversionService
from .models import Biomarker, UploadedMedicalReport
from .serializers import BiomarkerSerializer
from llm_model.gpt_model import GPTModel

logger = logging.getLogger(__name__)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_biomarkers(request):
    """
    Get all biomarkers for a user with trends and latest values
    Query params:
    - category: Filter by category (cardiovascular, liver, kidney, etc.)
    - only_with_data: Boolean, only return biomarkers with data
    - unit_system: Override user's preferred unit system (US or SI)
    - page: Page number (default: 1)
    - page_size: Number of items per page (default: 20, max: 100)
    """
    category = request.query_params.get('category')
    only_with_data = request.query_params.get('only_with_data', 'false').lower() == 'true'
    # Get unit system from query param or user preference
    unit_system = request.query_params.get('unit_system') or getattr(request.user, 'unit_system', 'US')

    # Pagination parameters
    page = int(request.query_params.get('page', 1))
    page_size = min(int(request.query_params.get('page_size', 20)), 100)  # Max 100 items per page

    try:
        biomarkers_with_trends = BiomarkerService.get_user_biomarkers_with_trends(
            user=request.user,
            category=category,
            only_with_data=only_with_data
        )

        # Apply unit conversions to all biomarkers
        for biomarker in biomarkers_with_trends:
            # Convert latest observation
            if biomarker.get('latestObservation'):
                obs = biomarker['latestObservation']
                converted = UnitConversionService.convert_biomarker({
                    'name': biomarker.get('definition', {}).get('name', ''),
                    'value': obs.get('value'),
                    'unit': obs.get('unit', '')
                }, unit_system)
                obs['value'] = converted['value']
                obs['unit'] = converted['unit']
                if 'original_value' in converted:
                    obs['original_value'] = converted['original_value']
                    obs['original_unit'] = converted['original_unit']

            # Convert recent observations
            if biomarker.get('recentObservations'):
                for obs in biomarker['recentObservations']:
                    converted = UnitConversionService.convert_biomarker({
                        'name': biomarker.get('definition', {}).get('name', ''),
                        'value': obs.get('value'),
                        'unit': obs.get('unit', '')
                    }, unit_system)
                    obs['value'] = converted['value']
                    obs['unit'] = converted['unit']

            # Update unit in definition
            if biomarker.get('definition'):
                preferred_unit = UnitConversionService.get_preferred_unit(
                    biomarker['definition'].get('name', ''),
                    unit_system
                )
                if preferred_unit:
                    biomarker['definition']['unit'] = preferred_unit

        # Apply pagination
        total_count = len(biomarkers_with_trends)
        total_pages = (total_count + page_size - 1) // page_size if page_size > 0 else 1
        start_index = (page - 1) * page_size
        end_index = start_index + page_size
        paginated_results = biomarkers_with_trends[start_index:end_index]

        return Response({
            'status': True,
            'count': len(paginated_results),
            'total_count': total_count,
            'page': page,
            'page_size': page_size,
            'total_pages': total_pages,
            'has_next': page < total_pages,
            'has_previous': page > 1,
            'unit_system': unit_system,
            'result': paginated_results
        })
    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to get biomarkers: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_biomarker_categories(request):
    """Get biomarker counts grouped by category"""
    try:
        categories = BiomarkerService.get_biomarker_categories(request.user)

        return Response({
            'status': True,
            'result': categories
        })
    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to get categories: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_biomarker_detail(request, biomarker_id):
    """
    Get detailed information about a specific biomarker
    Query params:
    - limit: Limit number of observations returned (default: 50)
    - unit_system: Override user's preferred unit system (US or SI)
    """
    limit = int(request.query_params.get('limit', 50))
    # Get unit system from query param or user preference
    unit_system = request.query_params.get('unit_system') or getattr(request.user, 'unit_system', 'US')

    try:
        # biomarker_id is actually the biomarker name or key
        biomarker_name = biomarker_id.replace('_', ' ').title()

        # Get all observations for this biomarker
        observations = list(Biomarker.objects.filter(
            user=request.user,
            name__iexact=biomarker_name
        ).order_by('-test_date')[:limit])

        if not observations:
            return Response({
                'status': False,
                'message': f'No data found for biomarker: {biomarker_name}'
            }, status=status.HTTP_404_NOT_FOUND)

        # Get biomarker definition
        definition = BiomarkerService.get_biomarker_definition(biomarker_name)
        if not definition:
            # Create basic definition
            definition = {
                'id': biomarker_id,
                'name': biomarker_name,
                'category': 'other',
                'loincCode': None,
                'unit': observations[0].unit if observations else None,
                'reference_ranges': [],
                'description': f'{biomarker_name} biomarker',
                'clinical_significance': None,
                'alternative_names': []
            }

        # Update unit in definition based on user preference
        preferred_unit = UnitConversionService.get_preferred_unit(biomarker_name, unit_system)
        if preferred_unit:
            definition['unit'] = preferred_unit

        # Calculate trend
        trend_direction, trend_percentage = BiomarkerService.calculate_trend(observations)

        # Serialize and convert observations
        serialized_observations = [BiomarkerService._serialize_observation(obs) for obs in observations]

        # Apply unit conversions to all observations
        for obs in serialized_observations:
            converted = UnitConversionService.convert_biomarker({
                'name': biomarker_name,
                'value': obs.get('value'),
                'unit': obs.get('unit', '')
            }, unit_system)
            obs['value'] = converted['value']
            obs['unit'] = converted['unit']
            if 'original_value' in converted:
                obs['original_value'] = converted['original_value']
                obs['original_unit'] = converted['original_unit']

        # Build response
        result = {
            'definition': definition,
            'latestObservation': serialized_observations[0] if serialized_observations else None,
            'recentObservations': serialized_observations,
            'trendDirection': trend_direction,
            'trendPercentage': trend_percentage,
            'totalObservations': Biomarker.objects.filter(
                user=request.user,
                name__iexact=biomarker_name
            ).count(),
            'unit_system': unit_system,
        }

        return Response({
            'status': True,
            'result': result
        })

    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to get biomarker detail: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_manual_observation(request):
    """
    Add a manual biomarker observation
    Body params:
    - biomarker_id: ID or name of the biomarker
    - value: Numeric value
    - unit: Unit of measurement
    - collected_at: ISO datetime string
    - notes: Optional notes
    """
    try:
        biomarker_id = request.data.get('biomarker_id')
        value = float(request.data.get('value'))
        unit = request.data.get('unit')
        collected_at = request.data.get('collected_at')
        notes = request.data.get('notes', '')

        if not all([biomarker_id, value is not None, unit, collected_at]):
            return Response({
                'status': False,
                'message': 'Missing required fields: biomarker_id, value, unit, collected_at'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Convert biomarker_id to name
        biomarker_name = biomarker_id.replace('_', ' ').title()

        # Get biomarker definition for reference ranges
        definition = BiomarkerService.get_biomarker_definition(biomarker_name)

        # Extract reference ranges from definition
        reference_min = None
        reference_max = None
        if definition and definition.get('reference_ranges'):
            ref_range = definition['reference_ranges'][0]  # Use first range for now
            reference_min = ref_range.get('low')
            reference_max = ref_range.get('high')

        # Create observation with manual entry flag
        observation = Biomarker.objects.create(
            user=request.user,
            report=None,  # Manual entry, no associated report
            name=biomarker_name,
            value=value,
            unit=unit,
            reference_min=reference_min,
            reference_max=reference_max,
            test_date=collected_at,
            notes=notes,
            is_manually_entered=True,  # Flag as manual entry
            extraction_confidence=1.0,  # Manual entries are 100% confident
        )

        # Calculate status
        observation_status = BiomarkerService.calculate_status(
            value, reference_min, reference_max
        )

        return Response({
            'status': True,
            'message': 'Observation added successfully',
            'result': BiomarkerService._serialize_observation(observation)
        }, status=status.HTTP_201_CREATED)

    except ValueError as e:
        return Response({
            'status': False,
            'message': f'Invalid value: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to add observation: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_labs_summary(request):
    """Get comprehensive lab summary for dashboard"""
    try:
        summary = BiomarkerService.get_labs_summary(request.user)

        return Response({
            'status': True,
            'result': summary
        })
    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to get labs summary: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_health_insights(request):
    """
    Get comprehensive health insights based on biomarker data
    Query params:
    - active_only: Boolean, only return insights for abnormal values (default: true)
    - include_normal: Boolean, include insights for normal values too (default: false)

    Returns detailed insights including:
    - What the abnormal value means
    - Severity level (critical, warning, info, success)
    - Urgency (urgent, soon, routine, none)
    - Recommended actions
    - Whether doctor visit is needed
    - Related tests to consider
    - Follow-up timeframe
    - Trend analysis
    """
    active_only = request.query_params.get('active_only', 'true').lower() == 'true'
    include_normal = request.query_params.get('include_normal', 'false').lower() == 'true'

    try:
        # Use the new comprehensive health insights system
        insights = BiomarkerService.get_all_health_insights(
            user=request.user,
            active_only=active_only and not include_normal
        )

        # Count by severity
        severity_counts = {
            'critical': 0,
            'warning': 0,
            'info': 0,
            'success': 0
        }
        for insight in insights:
            severity = insight.get('severity', 'info')
            if severity in severity_counts:
                severity_counts[severity] += 1

        # Count by urgency
        urgency_counts = {
            'urgent': 0,
            'soon': 0,
            'routine': 0,
            'none': 0
        }
        for insight in insights:
            urgency = insight.get('urgency', 'routine')
            if urgency in urgency_counts:
                urgency_counts[urgency] += 1

        # Get any critical insights that need immediate attention
        critical_insights = [i for i in insights if i.get('severity') == 'critical']
        requires_doctor = [i for i in insights if i.get('doctorNeeded')]

        return Response({
            'status': True,
            'count': len(insights),
            'summary': {
                'totalInsights': len(insights),
                'criticalCount': severity_counts['critical'],
                'warningCount': severity_counts['warning'],
                'urgentCount': urgency_counts['urgent'],
                'requiresDoctorVisit': len(requires_doctor),
                'hasUrgentItems': urgency_counts['urgent'] > 0,
                'hasCriticalItems': severity_counts['critical'] > 0,
            },
            'result': insights
        })

    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to get health insights: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def dismiss_insight(request, insight_id):
    """Dismiss a health insight"""
    # TODO: Implement insight dismissal with database tracking
    return Response({
        'status': True,
        'message': 'Insight dismissed'
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def search_biomarkers(request):
    """
    Search biomarker definitions
    Query params:
    - q: Search query
    """
    query = request.query_params.get('q', '')

    if not query or len(query) < 2:
        return Response({
            'status': False,
            'message': 'Query must be at least 2 characters'
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        results = BiomarkerService.search_biomarkers(query)

        return Response({
            'status': True,
            'count': len(results),
            'result': results
        })

    except Exception as e:
        return Response({
            'status': False,
            'message': f'Search failed: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def export_fhir(request):
    """
    Export biomarker data in FHIR format
    Query params:
    - from_date: ISO date string
    - to_date: ISO date string
    """
    # TODO: Implement FHIR export
    return Response({
        'status': True,
        'message': 'FHIR export not yet implemented',
        'result': {}
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_lab_documents(request):
    """
    Get lab documents for user
    Query params:
    - type: Document type filter
    - limit: Number of documents to return
    - offset: Pagination offset
    """
    document_type = request.query_params.get('type')
    limit = int(request.query_params.get('limit', 20))
    offset = int(request.query_params.get('offset', 0))

    try:
        queryset = UploadedMedicalReport.objects.filter(user=request.user)

        if document_type:
            # Filter by type if needed
            pass  # UploadedMedicalReport doesn't have type field yet

        queryset = queryset[offset:offset + limit]

        documents = []
        for doc in queryset:
            documents.append({
                'id': str(doc.id),
                'patientId': str(doc.user.id),
                'storagePath': doc.file.url if doc.file else '',
                'type': 'lab',
                'status': 'parsed' if doc.is_processed else 'pending',
                'uploadedAt': doc.uploaded_at.isoformat(),
                'processedAt': doc.reviewed_at.isoformat() if doc.reviewed_at else None,
                'summaryJson': doc.biomarkers,
                'originalFileName': doc.file_name,
                'fileSizeBytes': doc.file_size,
                'mimeType': doc.file_type,
            })

        return Response({
            'status': True,
            'count': len(documents),
            'result': documents
        })

    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to get documents: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_lab_document(request, document_id):
    """Delete a lab document"""
    try:
        document = UploadedMedicalReport.objects.get(
            id=document_id,
            user=request.user
        )
        document.delete()

        return Response({
            'status': True,
            'message': 'Document deleted successfully'
        })

    except UploadedMedicalReport.DoesNotExist:
        return Response({
            'status': False,
            'message': 'Document not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to delete document: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_all_lab_data(request):
    """
    Delete ALL lab data for the authenticated user
    This includes:
    - All biomarkers
    - All uploaded medical reports
    - All lab documents
    """
    try:
        user = request.user

        # Count before deletion
        biomarker_count = Biomarker.objects.filter(user=user).count()
        report_count = UploadedMedicalReport.objects.filter(user=user).count()

        # Delete all biomarkers for the user
        Biomarker.objects.filter(user=user).delete()

        # Delete all uploaded medical reports for the user
        UploadedMedicalReport.objects.filter(user=user).delete()

        return Response({
            'status': True,
            'message': 'All lab data deleted successfully',
            'deleted': {
                'biomarkers': biomarker_count,
                'reports': report_count
            }
        })
    except Exception as e:
        return Response({
            'status': False,
            'message': f'Failed to delete lab data: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reload_all_reports(request):
    """
    Re-analyze all uploaded medical reports for the authenticated user
    This will:
    - Delete all existing biomarker records
    - Re-process each uploaded report with latest AI
    - Extract and save new biomarker data
    """
    try:
        user = request.user

        # Get all uploaded reports for this user
        reports = UploadedMedicalReport.objects.filter(user=user, is_processed=True)

        if not reports.exists():
            return Response({
                'status': False,
                'message': 'No processed reports found to reload'
            }, status=status.HTTP_404_NOT_FOUND)

        # Delete all existing biomarkers for the user
        biomarker_count_before = Biomarker.objects.filter(user=user).count()
        Biomarker.objects.filter(user=user).delete()

        # Import the processor (avoiding circular import)
        from llm_model.medical_report_processor import MedicalReportProcessor
        from medicines.models import Medicine
        from datetime import datetime, date
        from django.utils import timezone

        processor = MedicalReportProcessor()
        reports_processed = 0
        biomarkers_created = 0
        errors = []

        # Re-process each report
        for report in reports:
            try:
                # Get user's current medications for comparison
                user_medications = Medicine.objects.filter(
                    user=user,
                    is_active=True
                ).values(
                    'drug_name', 'strength', 'strength_unit',
                    'instructions_text', 'schedule'
                )

                # Determine file type
                file_path = report.file.path
                file_type = 'pdf' if report.file_type == 'application/pdf' else 'image'

                # Process with AI
                result = processor.process_report(
                    file_path,
                    file_type,
                    list(user_medications)
                )

                # Update report with extracted data
                report.extracted_text = result['extracted_text']
                structured_data = result['structured_data']

                # Store biomarkers
                report.biomarkers = {
                    biomarker['name']: {
                        'value': biomarker['value'],
                        'unit': biomarker['unit'],
                        'reference_min': biomarker.get('reference_min'),
                        'reference_max': biomarker.get('reference_max'),
                        'flag': biomarker.get('flag')
                    }
                    for biomarker in structured_data.get('biomarkers', [])
                }

                # Store other data
                report.doctor_notes = structured_data.get('doctor_notes', '')
                report.diagnoses = structured_data.get('diagnoses', [])
                report.medication_recommendations = structured_data.get('medication_recommendations', [])

                # Update metadata if available
                if structured_data.get('report_date'):
                    try:
                        report.report_date = datetime.strptime(
                            structured_data['report_date'], '%Y-%m-%d'
                        ).date()
                    except:
                        pass

                if structured_data.get('provider_name') and not report.provider_name:
                    report.provider_name = structured_data['provider_name']

                if structured_data.get('facility_name') and not report.facility_name:
                    report.facility_name = structured_data['facility_name']

                report.is_processed = True
                report.status = 'reviewed'
                report.reviewed_at = timezone.now()
                report.save()

                # Get facility info for biomarkers
                facility_name = structured_data.get('facility_name') or report.facility_name
                provider_name = structured_data.get('provider_name') or report.provider_name
                laboratory_name = structured_data.get('laboratory_name')

                # Create or update Biomarker objects with enhanced conflict handling
                for biomarker_data in structured_data.get('biomarkers', []):
                    try:
                        test_date = datetime.strptime(
                            biomarker_data.get('test_date', str(date.today())),
                            '%Y-%m-%d'
                        ).date()
                    except:
                        test_date = date.today()

                    # Check for conflicts with existing biomarkers from different facilities
                    conflict_info = BiomarkerService.check_for_conflicts(
                        user=user,
                        biomarker_name=biomarker_data['name'],
                        test_date=test_date,
                        value=biomarker_data['value'],
                        facility_name=facility_name
                    )

                    # Use update_or_create with facility_name for unique constraint
                    biomarker, created = Biomarker.objects.update_or_create(
                        user=user,
                        name=biomarker_data['name'],
                        test_date=test_date,
                        facility_name=facility_name,  # Include facility for uniqueness
                        defaults={
                            'report': report,
                            'value': biomarker_data['value'],
                            'unit': biomarker_data['unit'],
                            'reference_min': biomarker_data.get('reference_min'),
                            'reference_max': biomarker_data.get('reference_max'),
                            'flag': biomarker_data.get('flag'),
                            'provider_name': provider_name,
                            'laboratory_name': laboratory_name,
                            'is_manually_entered': False,
                            'extraction_confidence': 0.9,  # AI extraction confidence
                            'has_conflict': conflict_info.get('has_conflicts', False),
                            'conflict_note': conflict_info.get('recommendation') if conflict_info.get('has_conflicts') else None,
                        }
                    )

                    if created:
                        biomarkers_created += 1

                reports_processed += 1

            except Exception as e:
                error_msg = f"Failed to process report {report.id}: {str(e)}"
                errors.append(error_msg)
                logger.exception("Failed to process report %s: %s", report.id, e)

        response_data = {
            'status': True,
            'message': f'Successfully reloaded {reports_processed} of {reports.count()} reports',
            'results': {
                'reports_processed': reports_processed,
                'total_reports': reports.count(),
                'biomarkers_before': biomarker_count_before,
                'biomarkers_created': biomarkers_created,
            }
        }

        if errors:
            response_data['errors'] = errors

        return Response(response_data)

    except Exception as e:
        logger.exception("Reload all reports failed: %s", e)
        return Response({
            'status': False,
            'message': f'Failed to reload reports: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_biomarker_ai_insights(request, biomarker_id):
    """
    Get AI-generated insights for a specific biomarker
    Returns:
    - clinical_significance: Personalized explanation of what the biomarker means for the user
    - related_insights: Insights based on other health data (meds, other biomarkers)
    - learn_more: Educational content about the biomarker
    """
    try:
        # Get biomarker name from ID
        biomarker_name = biomarker_id.replace('_', ' ').title()

        # Get unit system preference
        unit_system = request.query_params.get('unit_system') or getattr(request.user, 'unit_system', 'US')

        # Get user's observations for this biomarker
        observations = list(Biomarker.objects.filter(
            user=request.user,
            name__iexact=biomarker_name
        ).order_by('-test_date')[:10])

        if not observations:
            return Response({
                'status': False,
                'message': f'No data found for biomarker: {biomarker_name}'
            }, status=status.HTTP_404_NOT_FOUND)

        latest = observations[0]

        # Get biomarker definition for context
        definition = BiomarkerService.get_biomarker_definition(biomarker_name)

        # Get user's medications for context
        from medicines.models import Medicine
        from decimal import Decimal
        medications_raw = list(Medicine.objects.filter(
            user=request.user,
            is_active=True
        ).values('drug_name', 'strength', 'strength_unit', 'instructions_text'))

        # Convert Decimal values in medications to float for JSON serialization
        medications = []
        for med in medications_raw:
            medications.append({
                'drug_name': med['drug_name'],
                'strength': float(med['strength']) if isinstance(med['strength'], Decimal) else med['strength'],
                'strength_unit': med['strength_unit'],
                'instructions_text': med['instructions_text']
            })

        # Get other abnormal biomarkers for context
        other_biomarkers = BiomarkerService.get_user_biomarkers_with_trends(
            user=request.user,
            only_with_data=True
        )
        abnormal_biomarkers = [
            b for b in other_biomarkers
            if b.get('latestObservation', {}).get('status') in ['high', 'low', 'critical']
            and b.get('definition', {}).get('name', '').lower() != biomarker_name.lower()
        ][:5]  # Limit to 5 most relevant

        # Convert Decimal values in abnormal_biomarkers for JSON serialization
        def convert_decimals(obj):
            if isinstance(obj, Decimal):
                return float(obj)
            elif isinstance(obj, dict):
                return {k: convert_decimals(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_decimals(item) for item in obj]
            return obj

        abnormal_biomarkers = convert_decimals(abnormal_biomarkers)

        # Calculate trend
        trend_direction, trend_percentage = BiomarkerService.calculate_trend(observations)

        # Convert Decimal values to float for JSON serialization
        latest_value = float(latest.value) if latest.value is not None else None
        latest_ref_min = float(latest.reference_min) if latest.reference_min is not None else None
        latest_ref_max = float(latest.reference_max) if latest.reference_max is not None else None
        trend_pct = float(trend_percentage) if trend_percentage is not None else 0

        # Build context for AI
        observation_history = [
            {
                'date': obs.test_date.isoformat() if obs.test_date else None,
                'value': float(obs.value) if obs.value else None,
                'unit': obs.unit,
                'status': BiomarkerService.calculate_status(
                    float(obs.value) if obs.value else None,
                    float(obs.reference_min) if obs.reference_min else None,
                    float(obs.reference_max) if obs.reference_max else None
                )
            }
            for obs in observations[:5]
        ]

        # Build the prompt for OpenAI
        prompt = f"""You are a medical health assistant providing personalized insights about biomarker results.

BIOMARKER INFORMATION:
- Name: {biomarker_name}
- Latest Value: {latest_value} {latest.unit}
- Reference Range: {latest_ref_min if latest_ref_min is not None else 'N/A'} - {latest_ref_max if latest_ref_max is not None else 'N/A'} {latest.unit}
- Status: {BiomarkerService.calculate_status(latest_value, latest_ref_min, latest_ref_max)}
- Trend: {trend_direction} ({trend_pct}% change)
- Recent History: {json.dumps(observation_history)}

PATIENT CONTEXT:
- Current Medications: {json.dumps(medications) if medications else 'None listed'}
- Other Abnormal Biomarkers: {json.dumps([{'name': b.get('definition', {}).get('name'), 'value': b.get('latestObservation', {}).get('value'), 'status': b.get('latestObservation', {}).get('status')} for b in abnormal_biomarkers]) if abnormal_biomarkers else 'None'}

BIOMARKER DEFINITION (if available):
{json.dumps(convert_decimals(definition)) if definition else 'Standard clinical definition not available'}

Please provide a JSON response with the following structure:
{{
    "clinical_significance": {{
        "summary": "A 2-3 sentence personalized summary of what this result means for this patient",
        "interpretation": "Detailed interpretation of the current value considering the reference range and trend",
        "severity": "normal|mild|moderate|severe based on how far from normal",
        "trend_analysis": "Analysis of the trend direction and what it indicates"
    }},
    "related_insights": [
        {{
            "title": "Short insight title",
            "description": "Detailed insight connecting this biomarker to medications, other biomarkers, or lifestyle factors",
            "type": "medication|correlation|lifestyle|warning",
            "priority": "high|medium|low"
        }}
    ],
    "learn_more": {{
        "what_it_measures": "Simple explanation of what this biomarker tests",
        "why_it_matters": "Why this biomarker is important for health",
        "factors_affecting": ["List of factors that can affect this biomarker"],
        "lifestyle_tips": ["Actionable tips to improve or maintain healthy levels"],
        "when_to_seek_help": "When to consult a healthcare provider about this biomarker"
    }},
    "recommendations": [
        {{
            "action": "Specific actionable recommendation",
            "urgency": "immediate|soon|routine",
            "reason": "Why this action is recommended"
        }}
    ]
}}

Important guidelines:
- Be factual and evidence-based
- Personalize based on the patient's actual values and context
- If medications might affect this biomarker, mention it
- Identify correlations with other abnormal biomarkers
- Provide actionable, practical advice
- Use patient-friendly language
- Include appropriate medical disclaimers"""

        # Call OpenAI
        try:
            gpt = GPTModel()
            messages = [
                {"role": "system", "content": "You are a medical health assistant. Provide accurate, personalized health insights based on biomarker data. Always be factual and include appropriate disclaimers."},
                {"role": "user", "content": prompt}
            ]

            response = gpt.chat(messages, temperature=0.3)

            if response:
                ai_insights = json.loads(response)
            else:
                # Fallback response if AI fails
                ai_insights = _get_fallback_insights(biomarker_name, latest, trend_direction)

        except Exception as e:
            logger.warning("OpenAI call failed for biomarker insights: %s", e)
            ai_insights = _get_fallback_insights(biomarker_name, latest, trend_direction)

        return Response({
            'status': True,
            'biomarker': biomarker_name,
            'result': ai_insights
        })

    except Exception as e:
        logger.exception("Failed to get AI insights for biomarker: %s", e)
        return Response({
            'status': False,
            'message': f'Failed to get AI insights: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _get_fallback_insights(biomarker_name, latest_observation, trend_direction):
    """
    Provide fallback insights when AI is unavailable
    """
    status_text = BiomarkerService.calculate_status(
        float(latest_observation.value) if latest_observation.value else None,
        float(latest_observation.reference_min) if latest_observation.reference_min else None,
        float(latest_observation.reference_max) if latest_observation.reference_min else None
    )

    return {
        "clinical_significance": {
            "summary": f"Your {biomarker_name} level is {latest_observation.value} {latest_observation.unit}, which is {status_text}.",
            "interpretation": f"This value {'is within' if status_text == 'normal' else 'falls outside'} the reference range of {latest_observation.reference_min or 'N/A'} - {latest_observation.reference_max or 'N/A'} {latest_observation.unit}.",
            "severity": "normal" if status_text == "normal" else "mild",
            "trend_analysis": f"Your levels are trending {trend_direction}." if trend_direction != "stable" else "Your levels have been relatively stable."
        },
        "related_insights": [],
        "learn_more": {
            "what_it_measures": f"{biomarker_name} is a biomarker measured in blood tests.",
            "why_it_matters": "This biomarker provides insights into your health status.",
            "factors_affecting": ["Diet", "Exercise", "Medications", "Underlying conditions"],
            "lifestyle_tips": ["Maintain a balanced diet", "Exercise regularly", "Follow up with your healthcare provider"],
            "when_to_seek_help": "Consult your healthcare provider if you have concerns about your results or experience any symptoms."
        },
        "recommendations": [
            {
                "action": "Discuss these results with your healthcare provider",
                "urgency": "routine",
                "reason": "Regular monitoring helps track your health over time"
            }
        ]
    }


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_stored_health_insights(request):
    """
    Get stored AI-generated health insights for the user.
    These are automatically generated when lab reports are uploaded.

    Query params:
    - severity: Filter by severity (critical, warning, info, success)
    - include_dismissed: Include dismissed insights (default: false)
    - biomarker: Filter by biomarker name
    - report_id: Filter by report ID
    - limit: Number of insights to return (default: 50)
    - unread_only: Only return unread insights (default: false)
    """
    from .models import HealthInsight

    severity = request.query_params.get('severity')
    include_dismissed = request.query_params.get('include_dismissed', 'false').lower() == 'true'
    biomarker = request.query_params.get('biomarker')
    report_id = request.query_params.get('report_id')
    limit = int(request.query_params.get('limit', 50))
    unread_only = request.query_params.get('unread_only', 'false').lower() == 'true'

    try:
        queryset = HealthInsight.objects.filter(user=request.user)

        if not include_dismissed:
            queryset = queryset.filter(is_dismissed=False)

        if severity:
            queryset = queryset.filter(severity=severity)

        if biomarker:
            queryset = queryset.filter(biomarker_name__icontains=biomarker)

        if report_id:
            queryset = queryset.filter(report_id=report_id)

        if unread_only:
            queryset = queryset.filter(is_read=False)

        # Order by severity (critical first), then by date
        severity_order = {'critical': 0, 'warning': 1, 'info': 2, 'success': 3}
        insights = list(queryset.order_by('-created_at')[:limit])

        # Sort by severity priority
        insights.sort(key=lambda x: (severity_order.get(x.severity, 4), -x.created_at.timestamp()))

        # Count summaries
        all_insights = HealthInsight.objects.filter(user=request.user, is_dismissed=False)
        critical_count = all_insights.filter(severity='critical').count()
        warning_count = all_insights.filter(severity='warning').count()
        unread_count = all_insights.filter(is_read=False).count()
        requires_doctor = all_insights.filter(requires_doctor_visit=True).count()

        # Serialize insights
        result = []
        for insight in insights:
            result.append({
                'id': str(insight.id),
                'biomarkerName': insight.biomarker_name,
                'insightType': insight.insight_type,
                'title': insight.title,
                'summary': insight.summary,
                'detailedAnalysis': insight.detailed_analysis,
                'researchReferences': insight.research_references,
                'researchSummary': insight.research_summary,
                'biomarkerValue': insight.biomarker_value,
                'biomarkerUnit': insight.biomarker_unit,
                'referenceMin': insight.reference_min,
                'referenceMax': insight.reference_max,
                'status': insight.status,
                'deviationPercent': insight.deviation_percent,
                'trendDirection': insight.trend_direction,
                'trendPercentage': insight.trend_percentage,
                'previousValue': insight.previous_value,
                'severity': insight.severity,
                'urgency': insight.urgency,
                'recommendations': insight.recommendations,
                'doctorDiscussionPoints': insight.doctor_discussion_points,
                'lifestyleTips': insight.lifestyle_tips,
                'relatedBiomarkers': insight.related_biomarkers,
                'relatedMedications': insight.related_medications,
                'requiresDoctorVisit': insight.requires_doctor_visit,
                'isRead': insight.is_read,
                'isDismissed': insight.is_dismissed,
                'createdAt': insight.created_at.isoformat(),
                'reportId': str(insight.report_id) if insight.report_id else None,
            })

        return Response({
            'status': True,
            'count': len(result),
            'summary': {
                'criticalCount': critical_count,
                'warningCount': warning_count,
                'unreadCount': unread_count,
                'requiresDoctorVisit': requires_doctor,
                'hasCriticalItems': critical_count > 0,
                'hasWarningItems': warning_count > 0,
            },
            'result': result
        })

    except Exception as e:
        logger.exception("Failed to get stored health insights: %s", e)
        return Response({
            'status': False,
            'message': f'Failed to get health insights: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_insight_read(request, insight_id):
    """Mark a health insight as read"""
    from .models import HealthInsight

    try:
        insight = HealthInsight.objects.get(id=insight_id, user=request.user)
        insight.mark_as_read()

        return Response({
            'status': True,
            'message': 'Insight marked as read'
        })

    except HealthInsight.DoesNotExist:
        return Response({
            'status': False,
            'message': 'Insight not found'
        }, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def dismiss_health_insight(request, insight_id):
    """Dismiss a health insight"""
    from .models import HealthInsight

    try:
        insight = HealthInsight.objects.get(id=insight_id, user=request.user)
        insight.dismiss()

        return Response({
            'status': True,
            'message': 'Insight dismissed'
        })

    except HealthInsight.DoesNotExist:
        return Response({
            'status': False,
            'message': 'Insight not found'
        }, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def regenerate_report_insights(request, report_id):
    """
    Regenerate AI insights for a specific report.
    Useful if insights need to be updated with new context.
    """
    from .models import HealthInsight, UploadedMedicalReport
    from .insight_generation_service import InsightGenerationService

    try:
        report = UploadedMedicalReport.objects.get(id=report_id, user=request.user)

        # Delete existing insights for this report
        deleted_count = HealthInsight.objects.filter(report=report).delete()[0]

        # Get biomarkers from this report
        biomarkers = list(Biomarker.objects.filter(report=report))

        if not biomarkers:
            return Response({
                'status': False,
                'message': 'No biomarkers found for this report'
            }, status=status.HTTP_404_NOT_FOUND)

        # Generate new insights
        insights = InsightGenerationService.generate_insights_for_report(
            user=request.user,
            report=report,
            biomarkers=biomarkers
        )

        return Response({
            'status': True,
            'message': f'Regenerated {len(insights)} insights (deleted {deleted_count} old)',
            'insightsGenerated': len(insights)
        })

    except UploadedMedicalReport.DoesNotExist:
        return Response({
            'status': False,
            'message': 'Report not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.exception("Failed to regenerate insights: %s", e)
        return Response({
            'status': False,
            'message': f'Failed to regenerate insights: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
