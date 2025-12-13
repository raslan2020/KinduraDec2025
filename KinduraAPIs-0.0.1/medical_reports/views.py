import logging
from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.utils import timezone
from django.db.models import Q, Count
from utils.response_utils import success_response, error_response
from llm_model.medical_report_processor import MedicalReportProcessor
import os

logger = logging.getLogger(__name__)
from .models import (
    VitalSign, BloodTest, MedicalDocument, MedicalReport,
    UploadedMedicalReport, MedicationRecommendation, Biomarker
)
from .serializers import (
    VitalSignSerializer,
    BloodTestSerializer,
    MedicalDocumentSerializer,
    MedicalReportSerializer,
    UploadedMedicalReportSerializer,
    UploadedMedicalReportListSerializer,
    MedicationRecommendationSerializer,
    BiomarkerSerializer,
    ReportUploadSerializer
)
from medicines.models import Medicine
from medicines.serializers import MedicineSerializer
import json
import os
from datetime import datetime, date
from llm_model.gpt_model import GPTModel
from llm_model.pdf_markdown import pdf_to_markdown
from llm_model.medical_report_processor import MedicalReportProcessor


class VitalSignViewSet(viewsets.ModelViewSet):
    serializer_class = VitalSignSerializer

    def get_queryset(self):
        queryset = VitalSign.objects.filter(user=self.request.user)

        # Filter by date range if provided
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')

        if date_from:
            queryset = queryset.filter(recorded_at__gte=date_from)
        if date_to:
            queryset = queryset.filter(recorded_at__lte=date_to)

        return queryset

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class BloodTestViewSet(viewsets.ModelViewSet):
    serializer_class = BloodTestSerializer

    def get_queryset(self):
        queryset = BloodTest.objects.filter(user=self.request.user)

        # Filter by date range if provided
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')

        if date_from:
            queryset = queryset.filter(test_date__gte=date_from)
        if date_to:
            queryset = queryset.filter(test_date__lte=date_to)

        return queryset

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class MedicalDocumentViewSet(viewsets.ModelViewSet):
    serializer_class = MedicalDocumentSerializer
    parser_classes = (MultiPartParser, FormParser)

    def get_queryset(self):
        return MedicalDocument.objects.filter(user=self.request.user)

    def create(self, request, *args, **kwargs):
        # Handle file upload
        file = request.FILES.get('file')
        if not file:
            return Response(
                {'status': False, 'error': 'No file provided'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Create document instance
            document = MedicalDocument(
                user=request.user,
                title=request.data.get('title', file.name),
                document_type=request.data.get('document_type', 'other'),
                description=request.data.get('description', ''),
                file=file
            )
            document.save()

            # If it's a PDF file, try to process it with GPT for data extraction
            if file.name.lower().endswith('.pdf'):
                try:
                    # Process the uploaded PDF file directly
                    file_path = document.file.path

                    # Convert PDF to markdown
                    markdown = pdf_to_markdown(file_path)

                    # Prepare messages for GPT to extract medical data
                    messages = [
                        {"role": "system", "content": "Extract medical data from this document and return as JSON with fields: vital_signs (array), blood_tests (array), medications (array), notes (string)."},
                        {"role": "user", "content": markdown}
                    ]

                    gpt = GPTModel()
                    gpt_response = gpt.chat(messages)

                    if gpt_response:
                        try:
                            parsed_data = json.loads(gpt_response)
                            document.parsed_data = parsed_data
                            document.is_parsed = True
                            document.save()

                        except json.JSONDecodeError as e:
                            logger.warning("Failed to parse GPT response as JSON: %s", e)
                            # Document is still saved, just without parsed data
                    else:
                        logger.warning("GPT processing returned None")

                except Exception as e:
                    logger.error("Error processing PDF with GPT: %s", e)
                    # Document is still saved, just without parsed data

            serializer = self.get_serializer(document)
            return Response({
                'status': True,
                'result': serializer.data
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({
                'status': False,
                'result': {'error': str(e)}
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=True, methods=['post'])
    def parse(self, request, pk=None):
        """Parse uploaded document to extract medical data"""
        document = self.get_object()

        # Here you would implement actual document parsing logic
        # For now, we'll just mark it as parsed
        document.is_parsed = True
        document.parsed_data = {
            'medications': [],
            'vital_signs': [],
            'test_results': []
        }
        document.save()

        # TODO: Extract medications from parsed data and update medication schedules

        return Response({
            'status': True,
            'result': {
                'id': document.id,
                'parsed_data': document.parsed_data
            }
        })


class MedicalReportViewSet(viewsets.ViewSet):
    """Aggregated medical report endpoint"""

    def list(self, request):
        """Get complete medical report for the user"""
        # Get or create medical report for user
        report, created = MedicalReport.objects.get_or_create(user=request.user)

        # Manually build the response structure
        vital_signs = VitalSignSerializer(
            request.user.vital_signs.all(),
            many=True,
            context={'request': request}
        ).data

        blood_tests = BloodTestSerializer(
            request.user.blood_tests.all(),
            many=True,
            context={'request': request}
        ).data

        documents = MedicalDocumentSerializer(
            request.user.medical_documents.all(),
            many=True,
            context={'request': request}
        ).data

        return Response({
            'status': True,
            'result': {
                'vital_signs': vital_signs,
                'blood_tests': blood_tests,
                'documents': documents,
                'summary': report.summary,
                'last_updated': report.last_updated
            }
        })

    @action(detail=False, methods=['post'])
    def parse_report(self, request):
        """Parse a medical document and extract data"""
        document_id = request.data.get('document_id')

        if not document_id:
            return Response({
                'status': False,
                'error': 'document_id is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            document = MedicalDocument.objects.get(
                id=document_id,
                user=request.user
            )

            if document.is_parsed and document.parsed_data:
                # Already parsed, return existing data
                return Response({
                    'status': True,
                    'result': {
                        'id': document.id,
                        'parsed_data': document.parsed_data
                    }
                })

            # Try to parse the document if it's a PDF
            if document.file and document.file.name.lower().endswith('.pdf'):
                try:
                    file_path = document.file.path

                    # Convert PDF to markdown
                    markdown = pdf_to_markdown(file_path)

                    # Prepare messages for GPT to extract medical data
                    messages = [
                        {"role": "system", "content": "Extract medical data from this document and return as JSON with fields: vital_signs (array), blood_tests (array), medications (array), notes (string)."},
                        {"role": "user", "content": markdown}
                    ]

                    gpt = GPTModel()
                    gpt_response = gpt.chat(messages)

                    if gpt_response:
                        try:
                            parsed_data = json.loads(gpt_response)
                            document.parsed_data = parsed_data
                            document.is_parsed = True
                            document.save()

                            return Response({
                                'status': True,
                                'result': {
                                    'id': document.id,
                                    'parsed_data': document.parsed_data
                                }
                            })

                        except json.JSONDecodeError as e:
                            logger.warning("Failed to parse GPT response as JSON: %s", e)
                            return Response({
                                'status': False,
                                'error': f'Failed to parse document: Invalid JSON response from AI'
                            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
                    else:
                        return Response({
                            'status': False,
                            'error': 'AI processing failed. Please try again later.'
                        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

                except Exception as e:
                    logger.error("Error processing PDF with GPT: %s", e)
                    return Response({
                        'status': False,
                        'error': f'Error processing document: {str(e)}'
                    }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            else:
                # Not a PDF or no file, return basic parsed data
                document.is_parsed = True
                document.parsed_data = {
                    'medications': [],
                    'vital_signs': [],
                    'test_results': [],
                    'notes': 'Document processed without AI analysis'
                }
                document.save()

                return Response({
                    'status': True,
                    'result': {
                        'id': document.id,
                        'parsed_data': document.parsed_data
                    }
                })

        except MedicalDocument.DoesNotExist:
            return Response({
                'status': False,
                'error': 'Document not found'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({
                'status': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ==================== NEW MEDICAL REPORT UPLOAD SYSTEM ====================

class UploadedMedicalReportViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing uploaded medical reports with AI processing
    """
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.action == 'list':
            return UploadedMedicalReportListSerializer
        return UploadedMedicalReportSerializer

    def get_queryset(self):
        queryset = UploadedMedicalReport.objects.filter(user=self.request.user)

        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        # Filter by date range
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        if date_from:
            queryset = queryset.filter(uploaded_at__gte=date_from)
        if date_to:
            queryset = queryset.filter(uploaded_at__lte=date_to)

        return queryset.prefetch_related('recommendations', 'extracted_biomarkers')

    def list(self, request, *args, **kwargs):
        """Override list to return custom response format for Flutter app"""
        queryset = self.filter_queryset(self.get_queryset())
        serializer = self.get_serializer(queryset, many=True)
        return success_response(serializer.data)

    def destroy(self, request, *args, **kwargs):
        """Override destroy to return custom response format for Flutter app"""
        try:
            instance = self.get_object()
            instance.delete()
            return success_response(None, "Medical report deleted successfully")
        except Exception as e:
            return error_response(str(e), status.HTTP_400_BAD_REQUEST)

    def create(self, request, *args, **kwargs):
        """Upload and process a medical report"""
        logger.info("MEDICAL REPORT UPLOAD REQUEST - User: %s, Files: %s", request.user, request.FILES)

        serializer = ReportUploadSerializer(data=request.data, context={'request': request})

        if not serializer.is_valid():
            logger.warning("Validation failed: %s", serializer.errors)
            return Response({
                'status': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        uploaded_file = serializer.validated_data['file']
        report_date = serializer.validated_data.get('report_date')
        provider_name = serializer.validated_data.get('provider_name')
        facility_name = serializer.validated_data.get('facility_name')

        logger.info("File validated: %s (%d bytes)", uploaded_file.name, uploaded_file.size)

        try:
            # Create report instance
            logger.debug("Creating report in database...")
            report = UploadedMedicalReport.objects.create(
                user=request.user,
                file=uploaded_file,
                file_name=uploaded_file.name,
                file_type=uploaded_file.content_type,
                file_size=uploaded_file.size,
                report_date=report_date,
                provider_name=provider_name,
                facility_name=facility_name
            )
            logger.info("Report created with ID: %s, File saved to: %s", report.id, report.file.path if report.file else 'NOT SAVED')

            # Process the report in background (or synchronously for now)
            logger.debug("Processing report with AI...")
            try:
                self._process_report(report)
                logger.info("Report processed successfully")
            except Exception as process_error:
                logger.warning("Processing error (non-fatal): %s", process_error)
                report.processing_error = str(process_error)
                report.save()

            # Reload with related data
            report.refresh_from_db()
            response_serializer = UploadedMedicalReportSerializer(
                report,
                context={'request': request}
            )

            logger.info("Upload complete - Report ID: %s", report.id)

            return Response({
                'status': True,
                'message': 'Report uploaded and processed successfully',
                'result': response_serializer.data
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.exception("Upload failed: %s", e)
            return Response({
                'status': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def _process_report(self, report: UploadedMedicalReport):
        """Process uploaded report with AI to extract structured data"""
        try:
            # Get user's current medications for comparison
            user_medications = Medicine.objects.filter(
                user=report.user,
                is_active=True
            ).values(
                'drug_name', 'strength', 'strength_unit',
                'instructions_text', 'schedule'
            )

            # Determine file type
            file_path = report.file.path
            file_type = 'pdf' if report.file_type == 'application/pdf' else 'image'

            # Process with AI
            processor = MedicalReportProcessor()
            result = processor.process_report(
                file_path,
                file_type,
                list(user_medications)
            )

            # Update report with extracted data
            report.extracted_text = result['extracted_text']
            structured_data = result['structured_data']

            # Store biomarkers as a list to preserve time-series data
            # (dict would overwrite multiple readings for the same biomarker name)
            report.biomarkers = [
                {
                    'name': biomarker['name'],
                    'value': biomarker['value'],
                    'unit': biomarker['unit'],
                    'test_date': biomarker.get('test_date'),
                    'reference_min': biomarker.get('reference_min'),
                    'reference_max': biomarker.get('reference_max'),
                    'flag': biomarker.get('flag')
                }
                for biomarker in structured_data.get('biomarkers', [])
            ]

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

            # Import BiomarkerService for conflict checking
            from .biomarker_service import BiomarkerService

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
                    user=report.user,
                    biomarker_name=biomarker_data['name'],
                    test_date=test_date,
                    value=biomarker_data['value'],
                    facility_name=facility_name
                )

                # Use update_or_create with facility_name for unique constraint
                biomarker, created = Biomarker.objects.update_or_create(
                    user=report.user,
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

            # Create MedicationRecommendation objects
            for rec_data in structured_data.get('medication_recommendations', []):
                MedicationRecommendation.objects.create(
                    user=report.user,
                    report=report,
                    medication_name=rec_data['medication_name'],
                    brand_name=rec_data.get('brand_name'),
                    change_type=rec_data['change_type'],
                    old_value=rec_data.get('old_value'),
                    new_value=rec_data['new_value'],
                    reason=rec_data.get('reason', ''),
                    is_urgent=rec_data.get('is_urgent', False),
                    priority=rec_data.get('priority', 5)
                )

            # Generate AI-powered health insights for extracted biomarkers
            try:
                from .insight_generation_service import InsightGenerationService

                # Get the biomarkers we just created for this report
                report_biomarkers = list(Biomarker.objects.filter(report=report))

                if report_biomarkers:
                    logger.info(f"Generating AI insights for {len(report_biomarkers)} biomarkers from report {report.id}")
                    insights = InsightGenerationService.generate_insights_for_report(
                        user=report.user,
                        report=report,
                        biomarkers=report_biomarkers
                    )
                    logger.info(f"Generated {len(insights)} health insights for report {report.id}")
                else:
                    logger.info(f"No biomarkers found for report {report.id}, skipping insight generation")

            except Exception as insight_error:
                # Don't fail the entire report processing if insight generation fails
                logger.error(f"Failed to generate insights for report {report.id}: {insight_error}")
                # Optionally store the error for debugging
                report.processing_error = f"Report processed but insight generation failed: {insight_error}"
                report.save(update_fields=['processing_error'])

        except Exception as e:
            report.processing_error = str(e)
            report.is_processed = False
            report.save()
            raise

    @action(detail=True, methods=['post'])
    def reprocess(self, request, pk=None):
        """Reprocess a report with AI"""
        report = self.get_object()

        try:
            # Clear existing recommendations and biomarkers
            report.recommendations.all().delete()
            report.extracted_biomarkers.all().delete()

            # Reprocess
            self._process_report(report)

            report.refresh_from_db()
            serializer = self.get_serializer(report)

            return Response({
                'status': True,
                'message': 'Report reprocessed successfully',
                'result': serializer.data
            })

        except Exception as e:
            return Response({
                'status': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['get'])
    def latest(self, request):
        """Get the latest uploaded report"""
        latest_report = self.get_queryset().first()

        if not latest_report:
            return Response({
                'status': False,
                'message': 'No reports found'
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = self.get_serializer(latest_report)
        return Response({
            'status': True,
            'result': serializer.data
        })

    @action(detail=False, methods=['get'])
    def pending_recommendations(self, request):
        """Get all pending medication recommendations across all reports"""
        recommendations = MedicationRecommendation.objects.filter(
            user=request.user,
            status='pending'
        ).select_related('report')

        serializer = MedicationRecommendationSerializer(
            recommendations,
            many=True,
            context={'request': request}
        )

        return Response({
            'status': True,
            'count': recommendations.count(),
            'result': serializer.data
        })


class MedicationRecommendationViewSet(viewsets.ModelViewSet):
    """
    ViewSet for managing medication recommendations
    """
    serializer_class = MedicationRecommendationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = MedicationRecommendation.objects.filter(user=self.request.user)

        # Filter by status
        status_filter = self.request.query_params.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        # Filter by report
        report_id = self.request.query_params.get('report_id')
        if report_id:
            queryset = queryset.filter(report_id=report_id)

        return queryset.select_related('report', 'applied_medicine')

    @action(detail=True, methods=['post'])
    def apply(self, request, pk=None):
        """Mark recommendation as applied and optionally link to medicine"""
        recommendation = self.get_object()

        medicine_id = request.data.get('medicine_id')
        medicine = None

        if medicine_id:
            try:
                medicine = Medicine.objects.get(
                    id=medicine_id,
                    user=request.user
                )
            except Medicine.DoesNotExist:
                return Response({
                    'status': False,
                    'error': 'Medicine not found'
                }, status=status.HTTP_404_NOT_FOUND)

        recommendation.mark_as_applied(medicine)

        serializer = self.get_serializer(recommendation)
        return Response({
            'status': True,
            'message': 'Recommendation marked as applied',
            'result': serializer.data
        })

    @action(detail=True, methods=['post'])
    def dismiss(self, request, pk=None):
        """Dismiss a recommendation"""
        recommendation = self.get_object()
        reason = request.data.get('reason', '')

        recommendation.dismiss(reason)

        serializer = self.get_serializer(recommendation)
        return Response({
            'status': True,
            'message': 'Recommendation dismissed',
            'result': serializer.data
        })

    @action(detail=False, methods=['get'])
    def pending(self, request):
        """Get all pending recommendations for user"""
        recommendations = self.get_queryset().filter(status='pending')

        serializer = self.get_serializer(recommendations, many=True)
        return Response({
            'status': True,
            'count': recommendations.count(),
            'result': serializer.data
        })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_biomarkers(request):
    """Get biomarkers for authenticated user with optional filtering"""

    biomarker_name = request.query_params.get('name')
    date_from = request.query_params.get('date_from')
    date_to = request.query_params.get('date_to')

    queryset = Biomarker.objects.filter(user=request.user)

    if biomarker_name:
        queryset = queryset.filter(name__icontains=biomarker_name)

    if date_from:
        queryset = queryset.filter(test_date__gte=date_from)

    if date_to:
        queryset = queryset.filter(test_date__lte=date_to)

    serializer = BiomarkerSerializer(queryset, many=True)

    return Response({
        'status': True,
        'count': queryset.count(),
        'result': serializer.data
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_biomarker_trends(request, biomarker_name):
    """Get historical trend for a specific biomarker"""

    biomarkers = Biomarker.objects.filter(
        user=request.user,
        name__iexact=biomarker_name
    ).order_by('test_date')

    if not biomarkers.exists():
        return Response({
            'status': False,
            'message': f'No data found for biomarker: {biomarker_name}'
        }, status=status.HTTP_404_NOT_FOUND)

    serializer = BiomarkerSerializer(biomarkers, many=True)

    return Response({
        'status': True,
        'biomarker_name': biomarker_name,
        'count': biomarkers.count(),
        'result': serializer.data
    })
