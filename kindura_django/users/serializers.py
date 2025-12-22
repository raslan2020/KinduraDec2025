from rest_framework import serializers
from django.contrib.auth import authenticate
from django.core.exceptions import ValidationError
from .models import User, UserToken, Contact
from .models import UserJSON
from utils.authentication import create_user_token


class UserSignupSerializer(serializers.ModelSerializer):
    """
    Serializer for user signup
    """
    confirm_password = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ['email', 'password', 'confirm_password', 'username']
        extra_kwargs = {
            'password': {'write_only': True},
            'email': {'required': True},
        }
    
    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError("Passwords don't match")
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('confirm_password')
        user = User.objects.create_user(**validated_data)
        return user


class UserLoginSerializer(serializers.Serializer):
    """
    Serializer for user login
    """
    email = serializers.EmailField()
    password = serializers.CharField()
    
    def validate(self, attrs):
        email = attrs.get('email')
        password = attrs.get('password')
        
        if email and password:
            user = authenticate(username=email, password=password)
            if not user:
                raise serializers.ValidationError('Invalid email or password')
            attrs['user'] = user
        else:
            raise serializers.ValidationError('Must include email and password')
        
        return attrs


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for user profile
    """
    unit_system_display = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email', 'language', 'phone_number', 'age', 'gender', 'agent_conservation_choice', 'address', 'terms_and_conditions', 'unit_system', 'unit_system_display']
        extra_kwargs = {
            'terms_and_conditions': {'required': True},
            'unit_system': {'required': False}
        }

    def get_unit_system_display(self, obj):
        """Return human-readable unit system label"""
        unit_labels = {
            'US': 'US Standard (mg/dL, lbs, °F)',
            'SI': 'International SI (mmol/L, kg, °C)',
        }
        return unit_labels.get(obj.unit_system, obj.unit_system)
    
    def validate_terms_and_conditions(self, value):
        if not value:
            raise serializers.ValidationError("You must accept the terms and conditions")
        return value


class UserTokenSerializer(serializers.ModelSerializer):
    """
    Serializer for user tokens
    """
    class Meta:
        model = UserToken
        fields = ['token', 'created_at']


class UserJSONUploadSerializer(serializers.ModelSerializer):
    file = serializers.FileField(write_only=True)

    class Meta:
        model = UserJSON
        fields = ['id', 'uploaded_at', 'data', 'file', 'status', 'summarize_patient_report', 'error_message']
        read_only_fields = ['id', 'uploaded_at', 'data', 'status', 'summarize_patient_report', 'error_message']

    def create(self, validated_data):
        file = validated_data.pop('file')
        import json
        data = json.load(file)
        user = self.context['request'].user
        return UserJSON.objects.create(user=user, data=data)  # type: ignore[attr-defined]


class ContactSerializer(serializers.ModelSerializer):
    """
    Serializer for user contacts (family, caregivers, emergency contacts)
    """
    facetime_available = serializers.ReadOnlyField()
    facetime_target = serializers.ReadOnlyField()
    contact_type_display = serializers.SerializerMethodField()
    relationship_display = serializers.SerializerMethodField()

    class Meta:
        model = Contact
        fields = [
            'id', 'name', 'contact_type', 'contact_type_display',
            'relationship', 'relationship_display', 'phone_number',
            'email', 'is_emergency', 'is_primary', 'notes',
            'facetime_id', 'facetime_available', 'facetime_target',
            'created_at', 'updated_at', 'is_active'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'facetime_available', 'facetime_target']

    def get_contact_type_display(self, obj):
        return dict(Contact.CONTACT_TYPE_CHOICES).get(obj.contact_type, obj.contact_type)

    def get_relationship_display(self, obj):
        return dict(Contact.RELATIONSHIP_CHOICES).get(obj.relationship, obj.relationship)

    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class ContactListSerializer(serializers.ModelSerializer):
    """
    Lightweight serializer for listing contacts (for agent use)
    """
    class Meta:
        model = Contact
        fields = ['id', 'name', 'contact_type', 'relationship', 'phone_number', 'is_emergency', 'is_primary'] 