from rest_framework import serializers
from .models import (
    VitalSign, BloodTest, MedicalDocument, MedicalReport,
    UploadedMedicalReport, MedicationRecommendation, Biomarker
)
from django.contrib.auth.models import User


class VitalSignSerializer(serializers.ModelSerializer):
    class Meta:
        model = VitalSign
        fields = '__all__'
        read_only_fields = ('user', 'created_at', 'updated_at')


class BloodTestSerializer(serializers.ModelSerializer):
    class Meta:
        model = BloodTest
        fields = '__all__'
        read_only_fields = ('user', 'created_at', 'updated_at')


class MedicalDocumentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = MedicalDocument
        fields = '__all__'
        read_only_fields = ('user', 'uploaded_at', 'is_parsed')

    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
        return None


class MedicalReportSerializer(serializers.ModelSerializer):
    vital_signs = VitalSignSerializer(source='user.vital_signs', many=True, read_only=True)
    blood_tests = BloodTestSerializer(source='user.blood_tests', many=True, read_only=True)
    documents = MedicalDocumentSerializer(source='user.medical_documents', many=True, read_only=True)

    class Meta:
        model = MedicalReport
        fields = ['vital_signs', 'blood_tests', 'documents', 'summary', 'last_updated']
        read_only_fields = ('last_updated',)


class BiomarkerSerializer(serializers.ModelSerializer):
    is_out_of_range = serializers.ReadOnlyField()

    class Meta:
        model = Biomarker
        fields = [
            'id', 'user', 'report', 'name', 'value', 'unit',
            'reference_min', 'reference_max', 'is_normal', 'flag',
            'test_date', 'notes', 'created_at', 'is_out_of_range'
        ]
        read_only_fields = ('id', 'created_at', 'is_out_of_range')


class MedicationRecommendationSerializer(serializers.ModelSerializer):
    is_pending = serializers.ReadOnlyField()
    report_info = serializers.SerializerMethodField()

    class Meta:
        model = MedicationRecommendation
        fields = [
            'id', 'report', 'user', 'medication_name', 'brand_name',
            'change_type', 'old_value', 'new_value', 'reason', 'clinical_notes',
            'status', 'created_at', 'applied_at', 'dismissed_at', 'dismissal_reason',
            'applied_medicine', 'is_urgent', 'priority', 'is_pending', 'report_info'
        ]
        read_only_fields = ('id', 'created_at', 'applied_at', 'dismissed_at', 'is_pending')

    def get_report_info(self, obj):
        """Get basic info about the related report"""
        if obj.report:
            return {
                'id': str(obj.report.id),
                'file_name': obj.report.file_name,
                'uploaded_at': obj.report.uploaded_at
            }
        return None


class UploadedMedicalReportSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    recommendations_count = serializers.SerializerMethodField()
    pending_recommendations_count = serializers.SerializerMethodField()
    recommendations = MedicationRecommendationSerializer(many=True, read_only=True)
    extracted_biomarkers = BiomarkerSerializer(many=True, read_only=True)

    class Meta:
        model = UploadedMedicalReport
        fields = [
            'id', 'user', 'file', 'file_url', 'file_name', 'file_type', 'file_size',
            'extracted_text', 'biomarkers', 'doctor_notes', 'diagnoses',
            'medication_recommendations', 'report_date', 'provider_name', 'facility_name',
            'status', 'uploaded_at', 'reviewed_at', 'is_processed', 'processing_error',
            'recommendations_count', 'pending_recommendations_count',
            'recommendations', 'extracted_biomarkers'
        ]
        read_only_fields = ('id', 'uploaded_at', 'reviewed_at', 'file_url',
                           'recommendations_count', 'pending_recommendations_count')

    def get_file_url(self, obj):
        """Get absolute URL for uploaded file"""
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None

    def get_recommendations_count(self, obj):
        """Get total count of recommendations"""
        return obj.recommendations.count()

    def get_pending_recommendations_count(self, obj):
        """Get count of pending recommendations"""
        return obj.recommendations.filter(status='pending').count()


class UploadedMedicalReportListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for listing reports"""
    file_url = serializers.SerializerMethodField()
    pending_recommendations_count = serializers.SerializerMethodField()

    class Meta:
        model = UploadedMedicalReport
        fields = [
            'id', 'file_name', 'file_type', 'file_url', 'status',
            'uploaded_at', 'report_date', 'provider_name',
            'is_processed', 'pending_recommendations_count'
        ]

    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None

    def get_pending_recommendations_count(self, obj):
        return obj.recommendations.filter(status='pending').count()


class ReportUploadSerializer(serializers.Serializer):
    """Serializer for handling file uploads"""
    file = serializers.FileField(required=True)
    report_date = serializers.DateField(required=False, allow_null=True)
    provider_name = serializers.CharField(max_length=255, required=False, allow_blank=True)
    facility_name = serializers.CharField(max_length=255, required=False, allow_blank=True)

    def validate_file(self, value):
        """Validate uploaded file"""
        # Check file size (max 50MB)
        if value.size > 50 * 1024 * 1024:
            raise serializers.ValidationError("File size cannot exceed 50MB")

        # Check file type
        allowed_types = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg']
        if value.content_type not in allowed_types:
            raise serializers.ValidationError(
                "Only PDF and image files (JPEG, PNG) are allowed"
            )

        return value