"""
Biomarkers Service Layer
Handles business logic for biomarker management, trends analysis, and health insights
"""
from django.utils import timezone
from django.db.models import Q, Count, Avg, Max, Min
from datetime import timedelta, datetime
from typing import List, Dict, Optional, Tuple
from .models import Biomarker, UploadedMedicalReport
from collections import defaultdict
import statistics


class BiomarkerService:
    """Service for biomarker operations and analytics"""

    # Standard biomarker definitions with LOINC codes and reference ranges
    BIOMARKER_DEFINITIONS = {
        # Cardiovascular
        'total_cholesterol': {
            'name': 'Total Cholesterol',
            'category': 'cardiovascular',
            'loincCode': '2093-3',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': None, 'high': 200, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Total cholesterol in blood',
            'clinical_significance': 'High cholesterol increases risk of heart disease and stroke.',
            'alternative_names': ['Cholesterol', 'Chol', 'TC']
        },
        'ldl_cholesterol': {
            'name': 'LDL Cholesterol',
            'category': 'cardiovascular',
            'loincCode': '18262-6',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': None, 'high': 100, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Low-density lipoprotein cholesterol',
            'clinical_significance': 'LDL cholesterol is considered "bad" cholesterol.',
            'alternative_names': ['LDL', 'LDL-C', 'Bad Cholesterol']
        },
        'hdl_cholesterol': {
            'name': 'HDL Cholesterol',
            'category': 'cardiovascular',
            'loincCode': '2085-9',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': 40, 'high': None, 'gender': 'male', 'ageGroup': 'adult', 'unit': 'mg/dL'},
                {'low': 50, 'high': None, 'gender': 'female', 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'High-density lipoprotein cholesterol',
            'clinical_significance': 'HDL cholesterol is considered "good" cholesterol.',
            'alternative_names': ['HDL', 'HDL-C', 'Good Cholesterol']
        },
        'triglycerides': {
            'name': 'Triglycerides',
            'category': 'lipids',
            'loincCode': '2571-8',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': None, 'high': 150, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Triglycerides in blood',
            'clinical_significance': 'High triglycerides increase cardiovascular disease risk.',
            'alternative_names': ['TG', 'Trig']
        },

        # Diabetes / Metabolic
        'glucose': {
            'name': 'Glucose',
            'category': 'diabetes',
            'loincCode': '2345-7',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': 70, 'high': 100, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Fasting blood glucose',
            'clinical_significance': 'Elevated glucose indicates diabetes or prediabetes.',
            'alternative_names': ['Blood Sugar', 'FBS', 'Fasting Glucose']
        },
        'hba1c': {
            'name': 'HbA1c',
            'category': 'diabetes',
            'loincCode': '4548-4',
            'unit': '%',
            'reference_ranges': [
                {'low': None, 'high': 5.7, 'gender': None, 'ageGroup': 'adult', 'unit': '%'}
            ],
            'description': 'Glycated hemoglobin - 3-month average blood sugar',
            'clinical_significance': 'HbA1c reflects long-term blood sugar control.',
            'alternative_names': ['Hemoglobin A1c', 'A1C', 'Glycohemoglobin']
        },

        # Liver function
        'alt': {
            'name': 'ALT',
            'category': 'liver',
            'loincCode': '1742-6',
            'unit': 'U/L',
            'reference_ranges': [
                {'low': None, 'high': 40, 'gender': None, 'ageGroup': 'adult', 'unit': 'U/L'}
            ],
            'description': 'Alanine aminotransferase - liver enzyme',
            'clinical_significance': 'Elevated ALT indicates liver damage or inflammation.',
            'alternative_names': ['SGPT', 'Alanine Transaminase']
        },
        'ast': {
            'name': 'AST',
            'category': 'liver',
            'loincCode': '1920-8',
            'unit': 'U/L',
            'reference_ranges': [
                {'low': None, 'high': 40, 'gender': None, 'ageGroup': 'adult', 'unit': 'U/L'}
            ],
            'description': 'Aspartate aminotransferase - liver enzyme',
            'clinical_significance': 'Elevated AST may indicate liver or heart damage.',
            'alternative_names': ['SGOT', 'Aspartate Transaminase']
        },

        # Kidney function
        'creatinine': {
            'name': 'Creatinine',
            'category': 'kidney',
            'loincCode': '2160-0',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': 0.7, 'high': 1.3, 'gender': 'male', 'ageGroup': 'adult', 'unit': 'mg/dL'},
                {'low': 0.6, 'high': 1.1, 'gender': 'female', 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Creatinine - kidney function marker',
            'clinical_significance': 'Elevated creatinine indicates reduced kidney function.',
            'alternative_names': ['Cr', 'Serum Creatinine']
        },
        'bun': {
            'name': 'BUN',
            'category': 'kidney',
            'loincCode': '3094-0',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': 7, 'high': 20, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Blood urea nitrogen - kidney function',
            'clinical_significance': 'BUN measures kidney function and hydration.',
            'alternative_names': ['Blood Urea Nitrogen', 'Urea Nitrogen']
        },

        # Thyroid
        'tsh': {
            'name': 'TSH',
            'category': 'thyroid',
            'loincCode': '3016-3',
            'unit': 'mIU/L',
            'reference_ranges': [
                {'low': 0.4, 'high': 4.0, 'gender': None, 'ageGroup': 'adult', 'unit': 'mIU/L'}
            ],
            'description': 'Thyroid stimulating hormone',
            'clinical_significance': 'TSH measures thyroid function.',
            'alternative_names': ['Thyroid Stimulating Hormone', 'Thyrotropin']
        },

        # Inflammation
        'crp': {
            'name': 'C-Reactive Protein',
            'category': 'inflammation',
            'loincCode': '1988-5',
            'unit': 'mg/L',
            'reference_ranges': [
                {'low': None, 'high': 3.0, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/L'}
            ],
            'description': 'Marker of inflammation',
            'clinical_significance': 'Elevated CRP indicates inflammation or infection.',
            'alternative_names': ['CRP', 'hs-CRP']
        },

        # Vitamins
        'vitamin_d': {
            'name': 'Vitamin D',
            'category': 'nutrition',
            'loincCode': '1989-3',
            'unit': 'ng/mL',
            'reference_ranges': [
                {'low': 30, 'high': 100, 'gender': None, 'ageGroup': 'adult', 'unit': 'ng/mL'}
            ],
            'description': '25-hydroxyvitamin D',
            'clinical_significance': 'Vitamin D is essential for bone health and immunity.',
            'alternative_names': ['25-OH Vitamin D', '25(OH)D', 'Vit D']
        },
        'vitamin_b12': {
            'name': 'Vitamin B12',
            'category': 'nutrition',
            'loincCode': '2132-9',
            'unit': 'pg/mL',
            'reference_ranges': [
                {'low': 200, 'high': 900, 'gender': None, 'ageGroup': 'adult', 'unit': 'pg/mL'}
            ],
            'description': 'Vitamin B12 levels',
            'clinical_significance': 'B12 is essential for nerve function and red blood cell production.',
            'alternative_names': ['B12', 'Cobalamin']
        },

        # Hematology
        'hemoglobin': {
            'name': 'Hemoglobin',
            'category': 'hematology',
            'loincCode': '718-7',
            'unit': 'g/dL',
            'reference_ranges': [
                {'low': 13.5, 'high': 17.5, 'gender': 'male', 'ageGroup': 'adult', 'unit': 'g/dL'},
                {'low': 12.0, 'high': 16.0, 'gender': 'female', 'ageGroup': 'adult', 'unit': 'g/dL'}
            ],
            'description': 'Hemoglobin concentration in blood',
            'clinical_significance': 'Low hemoglobin indicates anemia; high may indicate polycythemia.',
            'alternative_names': ['Hgb', 'Hb']
        },
        'wbc': {
            'name': 'White Blood Cell Count',
            'category': 'hematology',
            'loincCode': '6690-2',
            'unit': 'x10^3/µL',
            'reference_ranges': [
                {'low': 4.5, 'high': 11.0, 'gender': None, 'ageGroup': 'adult', 'unit': 'x10^3/µL'}
            ],
            'description': 'White blood cell count',
            'clinical_significance': 'Elevated WBC indicates infection or inflammation; low may indicate immune issues.',
            'alternative_names': ['WBC', 'Leukocytes', 'White Blood Cells']
        },
        'platelets': {
            'name': 'Platelet Count',
            'category': 'hematology',
            'loincCode': '777-3',
            'unit': 'x10^3/µL',
            'reference_ranges': [
                {'low': 150, 'high': 400, 'gender': None, 'ageGroup': 'adult', 'unit': 'x10^3/µL'}
            ],
            'description': 'Platelet count in blood',
            'clinical_significance': 'Platelets are essential for blood clotting.',
            'alternative_names': ['PLT', 'Thrombocytes']
        },
        'rbc': {
            'name': 'Red Blood Cell Count',
            'category': 'hematology',
            'loincCode': '789-8',
            'unit': 'x10^6/µL',
            'reference_ranges': [
                {'low': 4.5, 'high': 5.5, 'gender': 'male', 'ageGroup': 'adult', 'unit': 'x10^6/µL'},
                {'low': 4.0, 'high': 5.0, 'gender': 'female', 'ageGroup': 'adult', 'unit': 'x10^6/µL'}
            ],
            'description': 'Red blood cell count',
            'clinical_significance': 'RBC count indicates oxygen-carrying capacity of blood.',
            'alternative_names': ['RBC', 'Red Blood Cells', 'Erythrocytes']
        },

        # Vital Signs
        'heart_rate': {
            'name': 'Heart Rate',
            'category': 'vitals',
            'loincCode': '8867-4',
            'unit': 'bpm',
            'reference_ranges': [
                {'low': 60, 'high': 100, 'gender': None, 'ageGroup': 'adult', 'unit': 'bpm'}
            ],
            'description': 'Heart rate in beats per minute',
            'clinical_significance': 'Heart rate reflects cardiovascular health and fitness.',
            'alternative_names': ['HR', 'Pulse', 'Pulse Rate']
        },
        'systolic_blood_pressure': {
            'name': 'Systolic Blood Pressure',
            'category': 'vitals',
            'loincCode': '8480-6',
            'unit': 'mmHg',
            'reference_ranges': [
                {'low': 90, 'high': 120, 'gender': None, 'ageGroup': 'adult', 'unit': 'mmHg'}
            ],
            'description': 'Systolic blood pressure (top number)',
            'clinical_significance': 'High systolic BP increases risk of heart disease and stroke.',
            'alternative_names': ['SBP', 'Systolic BP', 'Blood Pressure Systolic']
        },
        'diastolic_blood_pressure': {
            'name': 'Diastolic Blood Pressure',
            'category': 'vitals',
            'loincCode': '8462-4',
            'unit': 'mmHg',
            'reference_ranges': [
                {'low': 60, 'high': 80, 'gender': None, 'ageGroup': 'adult', 'unit': 'mmHg'}
            ],
            'description': 'Diastolic blood pressure (bottom number)',
            'clinical_significance': 'High diastolic BP indicates cardiovascular strain.',
            'alternative_names': ['DBP', 'Diastolic BP', 'Blood Pressure Diastolic']
        },
        'spo2': {
            'name': 'Oxygen Saturation',
            'category': 'vitals',
            'loincCode': '59408-5',
            'unit': '%',
            'reference_ranges': [
                {'low': 95, 'high': 100, 'gender': None, 'ageGroup': 'adult', 'unit': '%'}
            ],
            'description': 'Blood oxygen saturation level',
            'clinical_significance': 'Low SpO2 indicates respiratory issues or hypoxemia.',
            'alternative_names': ['SpO2', 'Oxygen Sat', 'O2 Saturation', 'Pulse Oximetry']
        },
        'hrv': {
            'name': 'Heart Rate Variability',
            'category': 'vitals',
            'loincCode': '80404-7',
            'unit': 'ms',
            'reference_ranges': [
                {'low': 20, 'high': 200, 'gender': None, 'ageGroup': 'adult', 'unit': 'ms'}
            ],
            'description': 'Heart rate variability - variation in time between heartbeats',
            'clinical_significance': 'Higher HRV indicates better cardiovascular fitness and stress resilience.',
            'alternative_names': ['HRV', 'Heart Variability']
        },

        # Iron Studies
        'ferritin': {
            'name': 'Ferritin',
            'category': 'nutrition',
            'loincCode': '2276-4',
            'unit': 'ng/mL',
            'reference_ranges': [
                {'low': 30, 'high': 400, 'gender': 'male', 'ageGroup': 'adult', 'unit': 'ng/mL'},
                {'low': 15, 'high': 150, 'gender': 'female', 'ageGroup': 'adult', 'unit': 'ng/mL'}
            ],
            'description': 'Ferritin - iron storage protein',
            'clinical_significance': 'Low ferritin indicates iron deficiency; high may indicate iron overload or inflammation.',
            'alternative_names': ['Serum Ferritin', 'Iron Storage']
        },

        # Fasting glucose alias
        'fasting_glucose': {
            'name': 'Fasting Glucose',
            'category': 'diabetes',
            'loincCode': '1558-6',
            'unit': 'mg/dL',
            'reference_ranges': [
                {'low': 70, 'high': 100, 'gender': None, 'ageGroup': 'adult', 'unit': 'mg/dL'}
            ],
            'description': 'Fasting blood glucose level',
            'clinical_significance': 'Elevated fasting glucose indicates diabetes or prediabetes.',
            'alternative_names': ['Fasting Blood Sugar', 'FBS', 'FBG', 'Fasting Blood Glucose']
        },
    }

    @staticmethod
    def get_biomarker_key(name: str) -> Optional[str]:
        """Find biomarker key from various name formats"""
        name_lower = name.lower().strip()

        # Direct match
        if name_lower in BiomarkerService.BIOMARKER_DEFINITIONS:
            return name_lower

        # Common name mappings for flexible matching
        # Supports both abbreviations and full standardized names from LLM output
        name_mappings = {
            # Lipids
            'ldl': 'ldl_cholesterol',
            'hdl': 'hdl_cholesterol',
            'ldl cholesterol': 'ldl_cholesterol',
            'hdl cholesterol': 'hdl_cholesterol',
            'ldl-c': 'ldl_cholesterol',
            'hdl-c': 'hdl_cholesterol',
            'tg': 'triglycerides',
            'trig': 'triglycerides',
            'total cholesterol': 'total_cholesterol',
            'cholesterol': 'total_cholesterol',

            # Liver
            'liver alt': 'alt',
            'liver ast': 'ast',
            'sgpt': 'alt',
            'sgot': 'ast',
            'alanine aminotransferase': 'alt',
            'aspartate aminotransferase': 'ast',

            # Diabetes
            'blood sugar': 'glucose',
            'fbs': 'fasting_glucose',
            'fbg': 'fasting_glucose',
            'fasting blood sugar': 'fasting_glucose',
            'fasting blood glucose': 'fasting_glucose',
            'hba1c': 'hba1c',
            'a1c': 'hba1c',
            'hemoglobin a1c': 'hba1c',
            'glycated hemoglobin': 'hba1c',

            # Vitamins
            'vitamin d': 'vitamin_d',
            'vit d': 'vitamin_d',
            '25-oh vitamin d': 'vitamin_d',
            '25-oh-d': 'vitamin_d',
            'b12': 'vitamin_b12',
            'vitamin b12': 'vitamin_b12',
            'cobalamin': 'vitamin_b12',

            # Inflammation
            'crp': 'crp',
            'c-reactive protein': 'crp',
            'hs-crp': 'crp',

            # Vitals
            'heart rate': 'heart_rate',
            'pulse': 'heart_rate',
            'pulse rate': 'heart_rate',
            'hr': 'heart_rate',
            'systolic bp': 'systolic_blood_pressure',
            'systolic blood pressure': 'systolic_blood_pressure',
            'sbp': 'systolic_blood_pressure',
            'diastolic bp': 'diastolic_blood_pressure',
            'diastolic blood pressure': 'diastolic_blood_pressure',
            'dbp': 'diastolic_blood_pressure',
            'spo2': 'spo2',
            'oxygen saturation': 'spo2',
            'o2 sat': 'spo2',
            'o2 saturation': 'spo2',
            'pulse oximetry': 'spo2',
            'hrv': 'hrv',
            'heart rate variability': 'hrv',

            # Hematology
            'wbc': 'wbc',
            'white blood cell': 'wbc',
            'white blood cells': 'wbc',
            'white blood cell count': 'wbc',
            'leukocytes': 'wbc',
            'rbc': 'rbc',
            'red blood cell': 'rbc',
            'red blood cells': 'rbc',
            'red blood cell count': 'rbc',
            'erythrocytes': 'rbc',
            'platelets': 'platelets',
            'platelet count': 'platelets',
            'plt': 'platelets',
            'thrombocytes': 'platelets',
            'hemoglobin': 'hemoglobin',
            'hgb': 'hemoglobin',
            'hb': 'hemoglobin',

            # Iron
            'ferritin': 'ferritin',
            'serum ferritin': 'ferritin',
            'iron storage': 'ferritin',

            # Thyroid
            'tsh': 'tsh',
            'thyroid stimulating hormone': 'tsh',
            'thyrotropin': 'tsh',

            # Kidney
            'creatinine': 'creatinine',
            'cr': 'creatinine',
            'serum creatinine': 'creatinine',
            'bun': 'bun',
            'blood urea nitrogen': 'bun',
            'urea nitrogen': 'bun',
        }

        # Check direct mapping
        if name_lower in name_mappings:
            return name_mappings[name_lower]

        # Check alternative names
        for key, definition in BiomarkerService.BIOMARKER_DEFINITIONS.items():
            if name_lower == definition['name'].lower():
                return key
            if 'alternative_names' in definition:
                for alt_name in definition['alternative_names']:
                    if name_lower == alt_name.lower():
                        return key

        # Partial match - check if name contains a key term
        for search_term, mapped_key in name_mappings.items():
            if search_term in name_lower or name_lower in search_term:
                return mapped_key

        return None

    @staticmethod
    def get_biomarker_definition(name: str) -> Optional[Dict]:
        """Get biomarker definition with normalized key"""
        key = BiomarkerService.get_biomarker_key(name)
        if key:
            definition = BiomarkerService.BIOMARKER_DEFINITIONS[key].copy()
            definition['id'] = key
            return definition
        return None

    @staticmethod
    def normalize_biomarker_name(name: str) -> str:
        """
        Normalize biomarker name to a standard form for consistent matching.
        Used for de-duplication and cross-facility comparison.

        Examples:
            "Total Cholesterol" -> "total_cholesterol"
            "LDL-C" -> "ldl_cholesterol"
            "HbA1c" -> "hba1c"
        """
        if not name:
            return ""

        # First try to map to a known biomarker key
        key = BiomarkerService.get_biomarker_key(name)
        if key:
            return key

        # Otherwise, normalize the name manually
        import re
        # Convert to lowercase
        normalized = name.lower().strip()
        # Replace common separators with underscore
        normalized = re.sub(r'[-\s/]+', '_', normalized)
        # Remove special characters except underscore
        normalized = re.sub(r'[^\w_]', '', normalized)
        # Remove duplicate underscores
        normalized = re.sub(r'_+', '_', normalized)
        # Remove leading/trailing underscores
        normalized = normalized.strip('_')

        return normalized

    @staticmethod
    def validate_biomarker_value(name: str, value: float, unit: str) -> Optional[str]:
        """
        Validate biomarker value against expected physiological ranges.
        Returns a warning message if the value seems implausible, None otherwise.

        This helps catch data entry errors or extraction issues.
        """
        if value is None:
            return None

        # Get biomarker definition
        key = BiomarkerService.get_biomarker_key(name)
        if not key:
            return None

        definition = BiomarkerService.BIOMARKER_DEFINITIONS.get(key, {})

        # Define physiologically plausible ranges (much wider than reference ranges)
        # These catch truly impossible values that indicate extraction errors
        PLAUSIBLE_RANGES = {
            'total_cholesterol': (50, 800),       # mg/dL
            'ldl_cholesterol': (10, 500),         # mg/dL
            'hdl_cholesterol': (5, 200),          # mg/dL
            'triglycerides': (20, 5000),          # mg/dL
            'glucose': (20, 800),                 # mg/dL
            'fasting_glucose': (20, 800),         # mg/dL
            'hba1c': (3.0, 20.0),                 # %
            'alt': (1, 10000),                    # U/L
            'ast': (1, 10000),                    # U/L
            'creatinine': (0.1, 30.0),            # mg/dL
            'bun': (1, 200),                      # mg/dL
            'tsh': (0.001, 100.0),                # mIU/L
            'crp': (0.01, 500.0),                 # mg/L
            'vitamin_d': (1, 200),                # ng/mL
            'vitamin_b12': (50, 5000),            # pg/mL
            'hemoglobin': (3.0, 25.0),            # g/dL
            'wbc': (0.5, 100.0),                  # x10^3/µL
            'platelets': (10, 1500),              # x10^3/µL
            'rbc': (1.0, 10.0),                   # x10^6/µL
            'ferritin': (1, 10000),               # ng/mL
            'heart_rate': (20, 250),              # bpm
            'systolic_blood_pressure': (50, 300), # mmHg
            'diastolic_blood_pressure': (20, 200),# mmHg
            'spo2': (50, 100),                    # %
            'hrv': (1, 500),                      # ms
        }

        if key in PLAUSIBLE_RANGES:
            min_val, max_val = PLAUSIBLE_RANGES[key]
            if value < min_val:
                return f"Value {value} {unit} is unusually low for {name}. Typical values are above {min_val}. Please verify."
            if value > max_val:
                return f"Value {value} {unit} is unusually high for {name}. Typical values are below {max_val}. Please verify."

        return None

    @staticmethod
    def convert_unit(value: float, from_unit: str, to_unit: str, biomarker_name: str) -> Optional[Tuple[float, str]]:
        """
        Convert biomarker value from one unit to another.
        Returns (converted_value, to_unit) or None if conversion not supported.

        Supports common unit conversions for lab values.
        """
        if not value or not from_unit or not to_unit:
            return None

        from_unit = from_unit.lower().strip()
        to_unit = to_unit.lower().strip()

        if from_unit == to_unit:
            return (value, to_unit)

        # Common conversions
        CONVERSIONS = {
            # Glucose: mg/dL <-> mmol/L (factor: 0.0555)
            ('glucose', 'mg/dl', 'mmol/l'): lambda v: v * 0.0555,
            ('glucose', 'mmol/l', 'mg/dl'): lambda v: v / 0.0555,
            ('fasting_glucose', 'mg/dl', 'mmol/l'): lambda v: v * 0.0555,
            ('fasting_glucose', 'mmol/l', 'mg/dl'): lambda v: v / 0.0555,

            # Cholesterol: mg/dL <-> mmol/L (factor: 0.0259)
            ('total_cholesterol', 'mg/dl', 'mmol/l'): lambda v: v * 0.0259,
            ('total_cholesterol', 'mmol/l', 'mg/dl'): lambda v: v / 0.0259,
            ('ldl_cholesterol', 'mg/dl', 'mmol/l'): lambda v: v * 0.0259,
            ('ldl_cholesterol', 'mmol/l', 'mg/dl'): lambda v: v / 0.0259,
            ('hdl_cholesterol', 'mg/dl', 'mmol/l'): lambda v: v * 0.0259,
            ('hdl_cholesterol', 'mmol/l', 'mg/dl'): lambda v: v / 0.0259,

            # Triglycerides: mg/dL <-> mmol/L (factor: 0.0113)
            ('triglycerides', 'mg/dl', 'mmol/l'): lambda v: v * 0.0113,
            ('triglycerides', 'mmol/l', 'mg/dl'): lambda v: v / 0.0113,

            # Creatinine: mg/dL <-> µmol/L (factor: 88.4)
            ('creatinine', 'mg/dl', 'µmol/l'): lambda v: v * 88.4,
            ('creatinine', 'µmol/l', 'mg/dl'): lambda v: v / 88.4,
            ('creatinine', 'mg/dl', 'umol/l'): lambda v: v * 88.4,
            ('creatinine', 'umol/l', 'mg/dl'): lambda v: v / 88.4,

            # BUN: mg/dL <-> mmol/L (factor: 0.357)
            ('bun', 'mg/dl', 'mmol/l'): lambda v: v * 0.357,
            ('bun', 'mmol/l', 'mg/dl'): lambda v: v / 0.357,

            # Vitamin D: ng/mL <-> nmol/L (factor: 2.496)
            ('vitamin_d', 'ng/ml', 'nmol/l'): lambda v: v * 2.496,
            ('vitamin_d', 'nmol/l', 'ng/ml'): lambda v: v / 2.496,

            # B12: pg/mL <-> pmol/L (factor: 0.738)
            ('vitamin_b12', 'pg/ml', 'pmol/l'): lambda v: v * 0.738,
            ('vitamin_b12', 'pmol/l', 'pg/ml'): lambda v: v / 0.738,

            # Hemoglobin: g/dL <-> g/L (factor: 10)
            ('hemoglobin', 'g/dl', 'g/l'): lambda v: v * 10,
            ('hemoglobin', 'g/l', 'g/dl'): lambda v: v / 10,
        }

        key = BiomarkerService.get_biomarker_key(biomarker_name)
        if not key:
            return None

        conversion_key = (key, from_unit, to_unit)
        if conversion_key in CONVERSIONS:
            converted = CONVERSIONS[conversion_key](value)
            return (round(converted, 2), to_unit)

        return None

    @staticmethod
    def check_for_conflicts(user, biomarker_name: str, test_date, value: float,
                            facility_name: str = None) -> Dict:
        """
        Check for potential conflicts with existing biomarker values.
        Returns conflict information if found.

        Used when uploading lab results from multiple sources.
        """
        from .models import Biomarker
        from datetime import timedelta

        normalized_name = BiomarkerService.normalize_biomarker_name(biomarker_name)

        # Look for existing biomarkers within a small date range (same day or adjacent days)
        date_range_start = test_date - timedelta(days=1)
        date_range_end = test_date + timedelta(days=1)

        existing = Biomarker.objects.filter(
            user=user,
            normalized_name=normalized_name,
            test_date__range=(date_range_start, date_range_end)
        ).exclude(
            facility_name=facility_name
        ) if facility_name else Biomarker.objects.filter(
            user=user,
            normalized_name=normalized_name,
            test_date__range=(date_range_start, date_range_end)
        )

        conflicts = []
        for existing_biomarker in existing:
            # Calculate difference percentage
            if existing_biomarker.value and value:
                diff_percent = abs((value - existing_biomarker.value) / existing_biomarker.value) * 100
            else:
                diff_percent = None

            conflicts.append({
                'existing_id': existing_biomarker.id,
                'existing_value': existing_biomarker.value,
                'existing_unit': existing_biomarker.unit,
                'existing_facility': existing_biomarker.facility_name,
                'existing_date': existing_biomarker.test_date,
                'new_value': value,
                'difference_percent': round(diff_percent, 1) if diff_percent else None,
                'is_significant': diff_percent and diff_percent > 10,  # >10% difference is significant
            })

        return {
            'has_conflicts': len(conflicts) > 0,
            'conflicts': conflicts,
            'recommendation': 'Both values may be valid if from different facilities or times. Consider marking the most recent as primary.' if conflicts else None
        }

    @staticmethod
    def calculate_status(value: float, reference_min: Optional[float], reference_max: Optional[float]) -> str:
        """
        Calculate biomarker status based on reference ranges
        Returns: low, normal, high, critical_low, critical_high, unknown
        """
        if value is None:
            return 'unknown'

        # Critical thresholds (2x outside range)
        if reference_max is not None:
            if value > reference_max * 1.5:
                return 'critical_high'
            elif value > reference_max:
                return 'high'

        if reference_min is not None:
            if value < reference_min * 0.5:
                return 'critical_low'
            elif value < reference_min:
                return 'low'

        # If we have at least one reference value and within range
        if reference_min is not None or reference_max is not None:
            return 'normal'

        return 'unknown'

    @staticmethod
    def calculate_trend(observations: List[Biomarker]) -> Tuple[str, Optional[float]]:
        """
        Calculate trend direction and percentage change
        Returns: (direction, percentage) where direction is improving, declining, stable, or insufficient_data
        """
        if len(observations) < 2:
            return ('insufficient_data', None)

        # Sort by date
        sorted_obs = sorted(observations, key=lambda x: x.test_date)

        # Use first half vs second half for trend
        midpoint = len(sorted_obs) // 2
        first_half = [obs.value for obs in sorted_obs[:midpoint]]
        second_half = [obs.value for obs in sorted_obs[midpoint:]]

        avg_first = statistics.mean(first_half)
        avg_second = statistics.mean(second_half)

        # Calculate percentage change
        if avg_first == 0:
            percentage = 0
        else:
            percentage = ((avg_second - avg_first) / avg_first) * 100

        # Determine if trend is improving or declining based on biomarker type
        # For most biomarkers, lower is better (cholesterol, glucose, etc.)
        # For some (HDL, Vitamin D), higher is better

        # Simple threshold: >5% change is significant
        if abs(percentage) < 5:
            return ('stable', percentage)
        elif percentage > 0:
            return ('declining', percentage)  # Assuming higher is worse for most
        else:
            return ('improving', percentage)

    @staticmethod
    def get_user_biomarkers_with_trends(user, category: Optional[str] = None, only_with_data: bool = False):
        """
        Get all biomarkers with latest values and trends for a user
        Returns data in the format expected by the frontend
        """
        results = []

        # Get all biomarker names for this user
        biomarker_names = Biomarker.objects.filter(user=user).values_list('name', flat=True).order_by('name').distinct('name')

        for name in biomarker_names:
            # Get biomarker definition
            definition = BiomarkerService.get_biomarker_definition(name)
            if not definition:
                # Create basic definition for unknown biomarkers
                definition = {
                    'id': name.lower().replace(' ', '_'),
                    'name': name,
                    'category': 'other',
                    'loincCode': None,
                    'unit': None,
                    'reference_ranges': [],
                    'description': f'{name} biomarker',
                    'clinical_significance': None,
                    'alternative_names': []
                }

            # Apply category filter
            if category and definition['category'].lower() != category.lower():
                continue

            # Get all observations for this biomarker
            observations = list(Biomarker.objects.filter(
                user=user,
                name__iexact=name
            ).order_by('-test_date'))

            # Skip if only_with_data and no observations
            if only_with_data and not observations:
                continue

            # Get latest observation
            latest_observation = observations[0] if observations else None

            # Calculate trend
            trend_direction, trend_percentage = BiomarkerService.calculate_trend(observations)

            # Build result
            result = {
                'definition': definition,
                'latestObservation': BiomarkerService._serialize_observation(latest_observation) if latest_observation else None,
                'recentObservations': [BiomarkerService._serialize_observation(obs) for obs in observations[:10]],
                'trendDirection': trend_direction,
                'trendPercentage': trend_percentage,
                'totalObservations': len(observations),
            }

            results.append(result)

        return results

    @staticmethod
    def _serialize_observation(biomarker: Biomarker) -> Dict:
        """Serialize a biomarker observation to match frontend expectations"""
        status = BiomarkerService.calculate_status(
            biomarker.value,
            biomarker.reference_min,
            biomarker.reference_max
        )

        return {
            'id': str(biomarker.id),
            'patientId': str(biomarker.user.id),
            'documentId': str(biomarker.report.id) if biomarker.report else None,
            'analyteName': biomarker.name,
            'normalizedName': getattr(biomarker, 'normalized_name', None),
            'loincCode': None,
            'valueNum': biomarker.value,
            'valueText': None,
            'unitOriginal': biomarker.unit,
            'unitUcum': biomarker.unit,
            'refLow': biomarker.reference_min,
            'refHigh': biomarker.reference_max,
            'refRange': f"{biomarker.reference_min} - {biomarker.reference_max}" if biomarker.reference_min and biomarker.reference_max else None,
            'status': status,
            'collectedAt': biomarker.test_date.isoformat(),
            'createdAt': biomarker.created_at.isoformat(),
            'notes': biomarker.notes,
            # Source tracking fields
            'facilityName': getattr(biomarker, 'facility_name', None),
            'providerName': getattr(biomarker, 'provider_name', None),
            'laboratoryName': getattr(biomarker, 'laboratory_name', None),
            # Data quality fields
            'extractionConfidence': getattr(biomarker, 'extraction_confidence', 1.0),
            'isManuallyEntered': getattr(biomarker, 'is_manually_entered', False),
            'isPrimary': getattr(biomarker, 'is_primary', True),
            'hasConflict': getattr(biomarker, 'has_conflict', False),
            'conflictNote': getattr(biomarker, 'conflict_note', None),
            # Validation fields
            'validationWarning': getattr(biomarker, 'validation_warning', None),
        }

    @staticmethod
    def get_labs_summary(user):
        """Get summary of all lab data for a user"""
        biomarkers = Biomarker.objects.filter(user=user)

        # Count abnormal and critical
        abnormal_count = 0
        critical_count = 0

        # Get latest observation for each biomarker type
        biomarker_names = biomarkers.values_list('name', flat=True).order_by('name').distinct('name')
        latest_biomarkers = []

        for name in biomarker_names:
            latest = biomarkers.filter(name=name).order_by('-test_date').first()
            if latest:
                latest_biomarkers.append(latest)
                status = BiomarkerService.calculate_status(
                    latest.value,
                    latest.reference_min,
                    latest.reference_max
                )
                if status in ['low', 'high']:
                    abnormal_count += 1
                if status in ['critical_low', 'critical_high']:
                    critical_count += 1

        # Get recent tests (last 30 days)
        thirty_days_ago = timezone.now().date() - timedelta(days=30)
        recent_tests_count = biomarkers.filter(test_date__gte=thirty_days_ago).values('report').distinct().count()

        # Get featured biomarkers (those with recent data or abnormal values)
        featured = BiomarkerService.get_user_biomarkers_with_trends(user, only_with_data=True)[:3]

        # Get active health insights
        active_insights = BiomarkerService.get_all_health_insights(user, active_only=True)[:5]  # Top 5 insights

        # Count insights that require doctor visit
        requires_doctor_count = len([i for i in active_insights if i.get('doctorNeeded')])
        urgent_count = len([i for i in active_insights if i.get('urgency') == 'urgent'])

        return {
            'totalBiomarkers': len(biomarker_names),
            'abnormalCount': abnormal_count,
            'criticalCount': critical_count,
            'recentTestsCount': recent_tests_count,
            'featuredBiomarkers': featured,
            'activeInsights': active_insights,
            'insightsSummary': {
                'total': len(active_insights),
                'requiresDoctor': requires_doctor_count,
                'urgent': urgent_count,
            },
            'lastUpdated': timezone.now().isoformat(),
        }

    @staticmethod
    def get_biomarker_categories(user) -> Dict[str, int]:
        """Get biomarker counts by category"""
        categories = defaultdict(int)

        biomarker_names = Biomarker.objects.filter(user=user).values_list('name', flat=True).order_by('name').distinct('name')

        for name in biomarker_names:
            definition = BiomarkerService.get_biomarker_definition(name)
            if definition:
                categories[definition['category']] += 1
            else:
                categories['other'] += 1

        return dict(categories)

    @staticmethod
    def search_biomarkers(query: str) -> List[Dict]:
        """Search biomarker definitions"""
        query_lower = query.lower()
        results = []

        for key, definition in BiomarkerService.BIOMARKER_DEFINITIONS.items():
            # Search in name
            if query_lower in definition['name'].lower():
                result = definition.copy()
                result['id'] = key
                results.append(result)
                continue

            # Search in alternative names
            if 'alternative_names' in definition:
                for alt_name in definition['alternative_names']:
                    if query_lower in alt_name.lower():
                        result = definition.copy()
                        result['id'] = key
                        results.append(result)
                        break

        return results

    # Comprehensive health insight definitions for each biomarker
    BIOMARKER_INSIGHTS = {
        'total_cholesterol': {
            'high': {
                'title': 'Elevated Total Cholesterol',
                'description': 'Your total cholesterol is above the recommended level. High cholesterol increases your risk of heart disease, stroke, and atherosclerosis.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Reduce intake of saturated and trans fats',
                    'Increase fiber intake with fruits, vegetables, and whole grains',
                    'Exercise for at least 30 minutes most days',
                    'Consider adding plant sterols to your diet',
                    'Limit dietary cholesterol from red meat and full-fat dairy'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Discuss statin therapy or other cholesterol-lowering medications if lifestyle changes are insufficient.',
                'related_tests': ['LDL Cholesterol', 'HDL Cholesterol', 'Triglycerides'],
                'timeframe': 'Recheck in 3-6 months after lifestyle modifications'
            },
            'critical_high': {
                'title': 'Significantly Elevated Total Cholesterol',
                'description': 'Your total cholesterol is significantly elevated, putting you at high risk for cardiovascular events. Immediate intervention is recommended.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Schedule a doctor appointment within 1-2 weeks',
                    'Begin strict dietary modifications immediately',
                    'Avoid all fried foods and processed snacks',
                    'Start daily cardiovascular exercise'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Medication therapy is likely necessary. Your doctor may order additional cardiac risk assessments.',
                'related_tests': ['LDL Cholesterol', 'Cardiac Risk Panel', 'Coronary Calcium Score'],
                'timeframe': 'Follow up within 4-6 weeks after starting treatment'
            }
        },
        'ldl_cholesterol': {
            'high': {
                'title': 'Elevated LDL ("Bad") Cholesterol',
                'description': 'Your LDL cholesterol is above optimal levels. LDL deposits cholesterol in artery walls, leading to plaque buildup and increased heart disease risk.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Limit saturated fat to less than 7% of daily calories',
                    'Avoid trans fats completely',
                    'Eat more soluble fiber (oats, beans, lentils)',
                    'Add omega-3 fatty acids (fish, walnuts, flaxseed)',
                    'Maintain a healthy weight'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Discuss your cardiovascular risk score and whether statin therapy is appropriate.',
                'related_tests': ['HDL Cholesterol', 'Triglycerides', 'Apolipoprotein B'],
                'timeframe': 'Recheck in 6-8 weeks after dietary changes'
            },
            'critical_high': {
                'title': 'Very High LDL Cholesterol',
                'description': 'Your LDL cholesterol is dangerously elevated. This significantly increases your risk of heart attack and stroke.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Contact your doctor within the next few days',
                    'Start intensive lifestyle modifications',
                    'Eliminate processed and fast foods',
                    'Consider cardiac stress testing'
                ],
                'doctor_needed': True,
                'doctor_reason': 'High-intensity statin therapy is typically recommended. Additional medications may be needed.',
                'related_tests': ['Cardiac CTA', 'Carotid Ultrasound'],
                'timeframe': 'Urgent follow-up within 2-4 weeks'
            }
        },
        'hdl_cholesterol': {
            'low': {
                'title': 'Low HDL ("Good") Cholesterol',
                'description': 'Your HDL cholesterol is below optimal levels. HDL helps remove harmful cholesterol from your bloodstream. Low HDL increases cardiovascular risk.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Exercise regularly - aim for 30+ minutes of aerobic activity',
                    'Quit smoking if applicable',
                    'Lose excess weight - even 5-10 lbs can help',
                    'Choose healthy fats (olive oil, avocados, nuts)',
                    'Limit refined carbohydrates and sugars'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Review your overall cardiovascular risk profile and discuss strategies to raise HDL.',
                'related_tests': ['LDL Cholesterol', 'Triglycerides'],
                'timeframe': 'Recheck in 3 months with exercise program'
            },
            'critical_low': {
                'title': 'Very Low HDL Cholesterol',
                'description': 'Your HDL cholesterol is critically low, indicating significantly reduced cardiovascular protection.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Consult doctor about potential causes',
                    'Rule out underlying conditions',
                    'Implement aggressive lifestyle changes',
                    'Consider genetic testing for lipid disorders'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Very low HDL may indicate metabolic syndrome or other conditions requiring treatment.',
                'related_tests': ['Metabolic Panel', 'Insulin Resistance Tests'],
                'timeframe': 'Follow up within 2-4 weeks'
            }
        },
        'triglycerides': {
            'high': {
                'title': 'Elevated Triglycerides',
                'description': 'Your triglyceride level is elevated. High triglycerides can contribute to hardening of arteries and increase risk of heart disease, heart attack, and stroke.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Limit sugar and refined carbohydrates',
                    'Reduce alcohol consumption significantly',
                    'Choose whole grains over white bread/pasta',
                    'Eat fatty fish twice a week',
                    'Exercise regularly to burn triglycerides'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Discuss whether medication is needed, especially if triglycerides remain high.',
                'related_tests': ['LDL Cholesterol', 'Blood Glucose', 'HbA1c'],
                'timeframe': 'Recheck in 2-3 months after dietary changes'
            },
            'critical_high': {
                'title': 'Very High Triglycerides',
                'description': 'Your triglycerides are dangerously elevated. Very high levels can cause pancreatitis, a serious medical condition.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Contact your doctor immediately',
                    'Eliminate alcohol completely',
                    'Strictly avoid sugary foods and drinks',
                    'Follow a very low-fat diet temporarily'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Urgent medication therapy needed to prevent pancreatitis. May need fibrates or high-dose omega-3s.',
                'related_tests': ['Lipase', 'Amylase', 'Pancreatic Function'],
                'timeframe': 'Urgent - within 1 week'
            }
        },
        'glucose': {
            'high': {
                'title': 'Elevated Blood Glucose',
                'description': 'Your blood glucose is above normal range. This may indicate prediabetes or diabetes, which can lead to serious health complications if untreated.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Reduce carbohydrate intake, especially refined carbs',
                    'Exercise regularly to improve insulin sensitivity',
                    'Maintain a healthy weight',
                    'Monitor blood sugar more frequently',
                    'Eat smaller, more frequent meals'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Get tested for HbA1c to assess long-term glucose control and discuss diabetes prevention strategies.',
                'related_tests': ['HbA1c', 'Fasting Insulin', 'Oral Glucose Tolerance Test'],
                'timeframe': 'Follow up within 1-2 months'
            },
            'critical_high': {
                'title': 'Significantly Elevated Blood Glucose',
                'description': 'Your blood glucose is significantly elevated, indicating possible diabetes that requires immediate attention.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Contact your doctor within a few days',
                    'Begin strict carbohydrate monitoring',
                    'Check for symptoms: increased thirst, frequent urination, fatigue',
                    'Avoid all sugary foods and drinks'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Diabetes diagnosis confirmation and treatment initiation needed. May require medication.',
                'related_tests': ['HbA1c', 'Kidney Function', 'Eye Exam'],
                'timeframe': 'See doctor within 1 week'
            },
            'low': {
                'title': 'Low Blood Glucose',
                'description': 'Your blood glucose is below normal range. This can cause symptoms like shakiness, confusion, and in severe cases, loss of consciousness.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Eat regular meals and snacks',
                    'Keep fast-acting glucose available',
                    'Avoid skipping meals',
                    'Monitor for symptoms: shakiness, sweating, hunger'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Investigate causes of low blood sugar - may indicate medication issues or other conditions.',
                'related_tests': ['Fasting Insulin', 'Cortisol', 'Liver Function'],
                'timeframe': 'Discuss at next appointment'
            }
        },
        'fasting_glucose': {
            'high': {
                'title': 'Elevated Fasting Glucose',
                'description': 'Your fasting glucose indicates your body may not be regulating blood sugar optimally. Values 100-125 mg/dL suggest prediabetes.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Lose 5-7% of body weight if overweight',
                    'Exercise 150 minutes per week',
                    'Choose low glycemic index foods',
                    'Increase fiber intake',
                    'Limit processed foods and added sugars'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Discuss prediabetes reversal strategies and consider metformin if lifestyle changes insufficient.',
                'related_tests': ['HbA1c', 'Oral Glucose Tolerance Test'],
                'timeframe': 'Recheck in 3 months after lifestyle changes'
            },
            'critical_high': {
                'title': 'Diabetic Range Fasting Glucose',
                'description': 'Your fasting glucose is in the diabetic range (≥126 mg/dL). This requires medical evaluation and treatment.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Schedule appointment with doctor this week',
                    'Begin monitoring blood glucose at home',
                    'Start diabetes-friendly diet immediately',
                    'Learn about carbohydrate counting'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Diabetes diagnosis confirmation needed. Treatment plan including medication should be started.',
                'related_tests': ['HbA1c', 'Kidney Function', 'Lipid Panel', 'Eye Exam'],
                'timeframe': 'See doctor within 1 week'
            }
        },
        'hba1c': {
            'high': {
                'title': 'Elevated HbA1c',
                'description': 'Your HbA1c is above normal, indicating higher than optimal blood sugar over the past 2-3 months. HbA1c 5.7-6.4% indicates prediabetes.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Review and improve your diet - reduce carbs and sugar',
                    'Increase physical activity',
                    'Monitor blood glucose regularly',
                    'Consider working with a diabetes educator',
                    'Focus on weight loss if overweight'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Discuss prediabetes management and monitor for progression to diabetes.',
                'related_tests': ['Fasting Glucose', 'Lipid Panel', 'Kidney Function'],
                'timeframe': 'Recheck HbA1c in 3 months'
            },
            'critical_high': {
                'title': 'Diabetic Range HbA1c',
                'description': 'Your HbA1c is in the diabetic range (≥6.5%), indicating diabetes that requires treatment to prevent complications.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Contact your doctor promptly',
                    'Begin strict diabetes management',
                    'Learn about diabetes and its management',
                    'Consider diabetes education program'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Diabetes treatment needed. Goal is typically HbA1c <7% to prevent complications.',
                'related_tests': ['Kidney Function', 'Eye Exam', 'Foot Exam', 'Cardiovascular Risk Assessment'],
                'timeframe': 'See doctor within 1-2 weeks; recheck HbA1c every 3 months'
            }
        },
        'alt': {
            'high': {
                'title': 'Elevated ALT (Liver Enzyme)',
                'description': 'Your ALT level is elevated, which may indicate liver inflammation or damage. ALT is specific to liver tissue.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Avoid alcohol completely',
                    'Review all medications and supplements with doctor',
                    'Maintain a healthy weight',
                    'Avoid acetaminophen (Tylenol) temporarily',
                    'Eat a liver-friendly diet low in processed foods'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Further testing needed to identify cause - could be fatty liver, hepatitis, or medication-related.',
                'related_tests': ['AST', 'Alkaline Phosphatase', 'Bilirubin', 'Hepatitis Panel', 'Liver Ultrasound'],
                'timeframe': 'Follow up within 2-4 weeks'
            },
            'critical_high': {
                'title': 'Significantly Elevated ALT',
                'description': 'Your ALT is markedly elevated, indicating significant liver stress or damage that requires prompt evaluation.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Contact your doctor immediately',
                    'Stop alcohol and unnecessary medications',
                    'Watch for jaundice (yellowing of skin/eyes)',
                    'Monitor for abdominal pain or nausea'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Urgent evaluation needed to rule out acute liver injury or hepatitis.',
                'related_tests': ['Complete Liver Panel', 'Hepatitis Panel', 'Liver Imaging'],
                'timeframe': 'See doctor within days'
            }
        },
        'ast': {
            'high': {
                'title': 'Elevated AST (Liver Enzyme)',
                'description': 'Your AST is elevated. While primarily a liver enzyme, AST can also rise with heart or muscle damage.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Avoid alcohol',
                    'Review medications with doctor',
                    'Avoid strenuous exercise before blood tests',
                    'Maintain healthy weight'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Need to determine if elevation is from liver, heart, or muscle. Compare with ALT level.',
                'related_tests': ['ALT', 'CK', 'Cardiac Enzymes', 'Liver Panel'],
                'timeframe': 'Follow up within 2-4 weeks'
            },
            'critical_high': {
                'title': 'Significantly Elevated AST',
                'description': 'Your AST is markedly elevated, indicating significant tissue damage requiring prompt investigation.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Contact your doctor immediately',
                    'Report any chest pain, muscle pain, or jaundice',
                    'Avoid all medications unless essential',
                    'Rest and monitor symptoms'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Urgent evaluation needed to identify source of tissue damage.',
                'related_tests': ['Complete Metabolic Panel', 'Cardiac Markers', 'Imaging'],
                'timeframe': 'See doctor within days'
            }
        },
        'creatinine': {
            'high': {
                'title': 'Elevated Creatinine',
                'description': 'Your creatinine level is above normal, which may indicate reduced kidney function. Kidneys filter creatinine from your blood.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Stay well hydrated with water',
                    'Avoid NSAIDs (ibuprofen, naproxen)',
                    'Limit protein intake temporarily',
                    'Control blood pressure if elevated',
                    'Avoid contrast dyes if possible'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Kidney function should be assessed. GFR calculation and further testing may be needed.',
                'related_tests': ['BUN', 'GFR', 'Urinalysis', 'Kidney Ultrasound'],
                'timeframe': 'Follow up within 1-2 weeks'
            },
            'critical_high': {
                'title': 'Significantly Elevated Creatinine',
                'description': 'Your creatinine is significantly elevated, indicating potential kidney dysfunction that requires urgent attention.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Contact your doctor today',
                    'Drink adequate water unless restricted',
                    'Avoid all nephrotoxic medications',
                    'Monitor urine output'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Urgent kidney function evaluation needed. May require referral to nephrologist.',
                'related_tests': ['Urgent Kidney Panel', 'Electrolytes', 'Kidney Ultrasound'],
                'timeframe': 'See doctor within 1-2 days'
            },
            'low': {
                'title': 'Low Creatinine',
                'description': 'Your creatinine is below normal range. This is often not concerning but may indicate low muscle mass.',
                'severity': 'info',
                'urgency': 'routine',
                'actions': [
                    'Consider strength training to build muscle',
                    'Ensure adequate protein intake',
                    'Generally not a concern unless symptomatic'
                ],
                'doctor_needed': False,
                'doctor_reason': 'Usually not clinically significant unless accompanied by other symptoms.',
                'related_tests': [],
                'timeframe': 'Routine monitoring'
            }
        },
        'bun': {
            'high': {
                'title': 'Elevated BUN',
                'description': 'Your blood urea nitrogen (BUN) is elevated. This can indicate kidney issues, dehydration, or high protein intake.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Increase water intake - aim for 8+ glasses daily',
                    'Reduce protein intake temporarily',
                    'Avoid NSAIDs',
                    'Monitor for signs of dehydration'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Compare with creatinine to assess kidney function. BUN/Creatinine ratio is informative.',
                'related_tests': ['Creatinine', 'GFR', 'Electrolytes'],
                'timeframe': 'Recheck after improving hydration (1-2 weeks)'
            },
            'low': {
                'title': 'Low BUN',
                'description': 'Your BUN is below normal range. This may indicate liver issues or inadequate protein intake.',
                'severity': 'info',
                'urgency': 'routine',
                'actions': [
                    'Ensure adequate protein in diet',
                    'Review liver function if other abnormalities present'
                ],
                'doctor_needed': False,
                'doctor_reason': 'Low BUN alone is rarely concerning but mention at next visit.',
                'related_tests': ['Liver Function Tests', 'Albumin'],
                'timeframe': 'Routine monitoring'
            }
        },
        'tsh': {
            'high': {
                'title': 'Elevated TSH (Hypothyroidism)',
                'description': 'Your TSH is elevated, indicating your thyroid may be underactive (hypothyroidism). This can cause fatigue, weight gain, and cold intolerance.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Monitor for symptoms: fatigue, weight gain, constipation, dry skin',
                    'Take any prescribed thyroid medication consistently',
                    'Avoid taking thyroid medication with calcium or iron supplements'
                ],
                'doctor_needed': True,
                'doctor_reason': 'May need thyroid hormone replacement therapy. Additional thyroid tests recommended.',
                'related_tests': ['Free T4', 'Free T3', 'Thyroid Antibodies'],
                'timeframe': 'Follow up within 4-6 weeks'
            },
            'low': {
                'title': 'Low TSH (Hyperthyroidism)',
                'description': 'Your TSH is low, indicating your thyroid may be overactive (hyperthyroidism). This can cause rapid heartbeat, weight loss, and anxiety.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Monitor for symptoms: rapid heartbeat, tremor, weight loss, anxiety',
                    'Avoid excessive caffeine',
                    'Report any heart palpitations to your doctor'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Hyperthyroidism evaluation needed. May require medication or further testing.',
                'related_tests': ['Free T4', 'Free T3', 'Thyroid Antibodies', 'Thyroid Uptake Scan'],
                'timeframe': 'Follow up within 2-4 weeks'
            }
        },
        'crp': {
            'high': {
                'title': 'Elevated C-Reactive Protein',
                'description': 'Your CRP is elevated, indicating inflammation in your body. This can be from infection, chronic disease, or cardiovascular risk.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Anti-inflammatory diet: more fruits, vegetables, omega-3s',
                    'Regular exercise reduces inflammation',
                    'Adequate sleep is important',
                    'Consider anti-inflammatory foods: turmeric, ginger, fatty fish'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Identify source of inflammation. May indicate cardiovascular risk or underlying condition.',
                'related_tests': ['ESR', 'CBC', 'Comprehensive Metabolic Panel'],
                'timeframe': 'Follow up in 4-6 weeks if no acute illness'
            },
            'critical_high': {
                'title': 'Significantly Elevated CRP',
                'description': 'Your CRP is significantly elevated, indicating substantial inflammation that may require investigation.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Look for signs of infection: fever, pain, swelling',
                    'Contact doctor if symptoms present',
                    'Rest and monitor temperature'
                ],
                'doctor_needed': True,
                'doctor_reason': 'High CRP may indicate infection, autoimmune condition, or acute illness requiring treatment.',
                'related_tests': ['CBC', 'Blood Cultures if febrile', 'Rheumatologic Panel'],
                'timeframe': 'See doctor within 1 week or immediately if symptomatic'
            }
        },
        'vitamin_d': {
            'low': {
                'title': 'Low Vitamin D',
                'description': 'Your Vitamin D level is below optimal. This can affect bone health, immune function, and mood.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Take Vitamin D3 supplement (typically 1000-4000 IU daily)',
                    'Get 15-20 minutes of sun exposure when possible',
                    'Eat Vitamin D rich foods: fatty fish, fortified milk, eggs',
                    'Take with fat for better absorption'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Discuss appropriate supplementation dose. Recheck levels after 2-3 months of supplementation.',
                'related_tests': ['Calcium', 'PTH', 'Bone Density if severe deficiency'],
                'timeframe': 'Recheck in 2-3 months after starting supplements'
            },
            'critical_low': {
                'title': 'Severe Vitamin D Deficiency',
                'description': 'Your Vitamin D is severely low (<10 ng/mL), which can cause bone pain, muscle weakness, and increased fracture risk.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Start high-dose Vitamin D supplementation immediately',
                    'Contact doctor for prescription-strength Vitamin D if needed',
                    'Monitor for bone pain or muscle weakness'
                ],
                'doctor_needed': True,
                'doctor_reason': 'May need prescription-strength Vitamin D (50,000 IU weekly). Bone health assessment recommended.',
                'related_tests': ['Calcium', 'PTH', 'Bone Density Scan'],
                'timeframe': 'Follow up within 2-4 weeks'
            },
            'high': {
                'title': 'High Vitamin D',
                'description': 'Your Vitamin D level is above the optimal range. Very high levels can cause toxicity.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Stop or reduce Vitamin D supplementation',
                    'Increase water intake',
                    'Avoid calcium supplements temporarily'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Assess for Vitamin D toxicity symptoms: nausea, weakness, kidney problems.',
                'related_tests': ['Calcium', 'Kidney Function'],
                'timeframe': 'Recheck in 4-6 weeks after stopping supplements'
            }
        },
        'vitamin_b12': {
            'low': {
                'title': 'Low Vitamin B12',
                'description': 'Your B12 is below optimal levels. B12 deficiency can cause fatigue, nerve problems, and anemia.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Take B12 supplement (oral or sublingual)',
                    'Eat B12-rich foods: meat, fish, eggs, dairy',
                    'If vegetarian/vegan, supplementation is essential',
                    'Consider B12 injections if absorption is impaired'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Determine if malabsorption is the cause. May need injections instead of oral supplements.',
                'related_tests': ['CBC', 'Methylmalonic Acid', 'Homocysteine'],
                'timeframe': 'Recheck in 2-3 months after supplementation'
            },
            'critical_low': {
                'title': 'Severely Low Vitamin B12',
                'description': 'Your B12 is critically low, which can cause irreversible neurological damage if untreated.',
                'severity': 'critical',
                'urgency': 'soon',
                'actions': [
                    'Contact your doctor promptly',
                    'Monitor for neurological symptoms: numbness, tingling, balance issues',
                    'Start high-dose B12 immediately'
                ],
                'doctor_needed': True,
                'doctor_reason': 'B12 injections likely needed. Neurological assessment may be required.',
                'related_tests': ['CBC', 'Neurological Exam'],
                'timeframe': 'See doctor within 1 week'
            }
        },
        'hemoglobin': {
            'low': {
                'title': 'Low Hemoglobin (Anemia)',
                'description': 'Your hemoglobin is below normal, indicating anemia. This reduces oxygen delivery to tissues, causing fatigue and weakness.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Eat iron-rich foods: red meat, spinach, beans, fortified cereals',
                    'Take iron supplements if recommended',
                    'Pair iron with Vitamin C for better absorption',
                    'Avoid coffee/tea with iron supplements'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Determine cause of anemia: iron deficiency, B12/folate deficiency, chronic disease, or bleeding.',
                'related_tests': ['Iron Studies', 'B12', 'Folate', 'Reticulocyte Count'],
                'timeframe': 'Follow up within 2-4 weeks'
            },
            'critical_low': {
                'title': 'Severe Anemia',
                'description': 'Your hemoglobin is dangerously low. Severe anemia can cause shortness of breath, rapid heartbeat, and dizziness.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Contact your doctor immediately',
                    'Rest and avoid strenuous activity',
                    'Report any chest pain or severe shortness of breath'
                ],
                'doctor_needed': True,
                'doctor_reason': 'May need blood transfusion or urgent treatment. ER visit if symptomatic.',
                'related_tests': ['Urgent CBC', 'Type and Screen'],
                'timeframe': 'See doctor today or go to ER if symptomatic'
            },
            'high': {
                'title': 'Elevated Hemoglobin',
                'description': 'Your hemoglobin is above normal range. This can be from dehydration, lung disease, or polycythemia.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Stay well hydrated',
                    'Avoid smoking',
                    'Monitor for symptoms: headache, dizziness, vision changes'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Evaluate for causes including dehydration, lung disease, or polycythemia vera.',
                'related_tests': ['Hematocrit', 'Oxygen Saturation', 'EPO Level'],
                'timeframe': 'Follow up within 2-4 weeks'
            }
        },
        'wbc': {
            'high': {
                'title': 'Elevated White Blood Cells',
                'description': 'Your WBC count is elevated, usually indicating your immune system is fighting an infection or inflammation.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Monitor for signs of infection: fever, pain, swelling',
                    'Rest and stay hydrated',
                    'Practice good hygiene',
                    'Complete any prescribed antibiotics'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Identify cause of elevated WBC. May be infection, inflammation, or rarely leukemia.',
                'related_tests': ['WBC Differential', 'CRP', 'Blood Cultures if febrile'],
                'timeframe': 'Recheck after infection resolves; urgent if very high'
            },
            'low': {
                'title': 'Low White Blood Cells',
                'description': 'Your WBC count is low, which may reduce your ability to fight infections.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Practice good hand hygiene',
                    'Avoid sick contacts',
                    'Report any fever or signs of infection immediately',
                    'Ensure food safety - avoid raw/undercooked foods'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Evaluate cause: medication side effect, viral infection, or bone marrow issue.',
                'related_tests': ['WBC Differential', 'B12', 'Folate', 'Viral Panel'],
                'timeframe': 'Follow up within 1-2 weeks'
            }
        },
        'platelets': {
            'low': {
                'title': 'Low Platelet Count',
                'description': 'Your platelet count is below normal. Platelets help blood clot, so low levels increase bleeding risk.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Avoid aspirin and NSAIDs',
                    'Be careful to avoid cuts and injuries',
                    'Report any unusual bruising or bleeding',
                    'Use soft toothbrush'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Determine cause: medication, infection, autoimmune, or bone marrow issue.',
                'related_tests': ['Peripheral Blood Smear', 'Coagulation Tests', 'Bone Marrow Biopsy if severe'],
                'timeframe': 'Follow up within 1-2 weeks; urgent if very low'
            },
            'critical_low': {
                'title': 'Critically Low Platelets',
                'description': 'Your platelets are dangerously low, putting you at significant risk for bleeding.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Contact your doctor immediately',
                    'Avoid all injury risk',
                    'Do not take any medications without approval',
                    'Go to ER if any bleeding occurs'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Urgent evaluation needed. May require platelet transfusion or specific treatment.',
                'related_tests': ['Urgent CBC', 'Coagulation Panel'],
                'timeframe': 'See doctor today'
            },
            'high': {
                'title': 'Elevated Platelet Count',
                'description': 'Your platelet count is above normal, which can increase risk of blood clots.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Stay well hydrated',
                    'Stay active and avoid prolonged sitting',
                    'Report any leg swelling, pain, or shortness of breath'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Evaluate for reactive causes (infection, inflammation) vs. primary blood disorders.',
                'related_tests': ['Iron Studies', 'CRP', 'JAK2 Mutation if very high'],
                'timeframe': 'Follow up within 2-4 weeks'
            }
        },
        'ferritin': {
            'low': {
                'title': 'Low Ferritin (Iron Stores)',
                'description': 'Your ferritin is low, indicating depleted iron stores. This often precedes iron-deficiency anemia.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Eat iron-rich foods: red meat, poultry, fish, beans, spinach',
                    'Take iron supplement with Vitamin C',
                    'Avoid coffee/tea around supplement time',
                    'Cook in cast iron cookware'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Investigate cause of iron deficiency: diet, malabsorption, or blood loss.',
                'related_tests': ['Complete Iron Panel', 'CBC', 'Stool Occult Blood'],
                'timeframe': 'Recheck in 2-3 months after supplementation'
            },
            'high': {
                'title': 'Elevated Ferritin',
                'description': 'Your ferritin is elevated. This can indicate iron overload, inflammation, or liver disease.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Avoid iron supplements and high-iron foods',
                    'Limit alcohol consumption',
                    'Avoid Vitamin C supplements (increases iron absorption)'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Distinguish between iron overload and inflammation. Genetic testing for hemochromatosis may be needed.',
                'related_tests': ['Iron Saturation', 'Liver Function', 'CRP', 'HFE Gene Test'],
                'timeframe': 'Follow up within 2-4 weeks'
            }
        },
        'heart_rate': {
            'high': {
                'title': 'Elevated Heart Rate',
                'description': 'Your resting heart rate is above normal. This can indicate stress, deconditioning, or cardiac issues.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Reduce caffeine and alcohol intake',
                    'Practice stress reduction techniques',
                    'Regular aerobic exercise improves heart rate over time',
                    'Ensure adequate sleep'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Evaluate for underlying causes: thyroid, anemia, cardiac arrhythmia.',
                'related_tests': ['TSH', 'CBC', 'ECG', 'Echocardiogram if indicated'],
                'timeframe': 'Routine follow-up unless very elevated or symptomatic'
            },
            'low': {
                'title': 'Low Heart Rate (Bradycardia)',
                'description': 'Your heart rate is below normal range. This can be normal in athletes but may indicate heart conduction issues.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Monitor for symptoms: dizziness, fatigue, fainting',
                    'Note any medications that slow heart rate',
                    'If symptomatic, seek evaluation'
                ],
                'doctor_needed': True,
                'doctor_reason': 'May need ECG to assess heart rhythm. Symptomatic bradycardia requires evaluation.',
                'related_tests': ['ECG', 'Holter Monitor'],
                'timeframe': 'Routine unless symptomatic'
            }
        },
        'systolic_blood_pressure': {
            'high': {
                'title': 'Elevated Blood Pressure',
                'description': 'Your systolic blood pressure is above normal. High blood pressure significantly increases risk of heart attack, stroke, and kidney disease.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Reduce sodium intake to <2300mg daily',
                    'Follow DASH diet rich in fruits and vegetables',
                    'Exercise 30 minutes most days',
                    'Limit alcohol to 1-2 drinks per day',
                    'Maintain healthy weight',
                    'Manage stress'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Blood pressure medication may be needed if lifestyle changes insufficient.',
                'related_tests': ['Kidney Function', 'Electrolytes', 'Lipid Panel'],
                'timeframe': 'Recheck in 2-4 weeks with lifestyle modifications'
            },
            'critical_high': {
                'title': 'Severely Elevated Blood Pressure',
                'description': 'Your blood pressure is dangerously high. Very high BP can cause stroke, heart attack, or kidney damage.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'Sit quietly and rest',
                    'Recheck blood pressure after 5 minutes of rest',
                    'If symptoms present (headache, vision changes, chest pain), seek emergency care',
                    'Contact your doctor today'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Urgent evaluation needed. Medication adjustment or initiation likely required.',
                'related_tests': ['Urgent Kidney Function', 'ECG', 'Urinalysis'],
                'timeframe': 'See doctor within 1-2 days or ER if symptomatic'
            }
        },
        'diastolic_blood_pressure': {
            'high': {
                'title': 'Elevated Diastolic Blood Pressure',
                'description': 'Your diastolic (bottom number) blood pressure is elevated, indicating increased pressure when your heart rests between beats.',
                'severity': 'warning',
                'urgency': 'routine',
                'actions': [
                    'Follow same lifestyle modifications as for systolic BP',
                    'Reduce salt intake',
                    'Exercise regularly',
                    'Maintain healthy weight'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Evaluate need for blood pressure medication.',
                'related_tests': ['Same as systolic BP'],
                'timeframe': 'Recheck in 2-4 weeks'
            }
        },
        'spo2': {
            'low': {
                'title': 'Low Oxygen Saturation',
                'description': 'Your blood oxygen level is below normal. This can indicate respiratory or cardiac issues.',
                'severity': 'critical',
                'urgency': 'urgent',
                'actions': [
                    'If significantly low (<90%), seek immediate medical care',
                    'Sit upright to improve breathing',
                    'Use supplemental oxygen if prescribed',
                    'Report any shortness of breath or chest pain'
                ],
                'doctor_needed': True,
                'doctor_reason': 'Low oxygen requires urgent evaluation. May indicate pneumonia, COPD, heart failure, or COVID-19.',
                'related_tests': ['Arterial Blood Gas', 'Chest X-ray', 'Pulmonary Function Tests'],
                'timeframe': 'Immediate if <90%; same day if 90-94%'
            }
        }
    }

    @staticmethod
    def generate_health_insight(biomarker_name: str, value: float, status: str,
                                 reference_min: float = None, reference_max: float = None,
                                 trend_direction: str = None) -> Optional[Dict]:
        """
        Generate detailed health insight for a biomarker based on its value and status.
        Returns comprehensive insight with actions, recommendations, and urgency.
        """
        biomarker_key = BiomarkerService.get_biomarker_key(biomarker_name)
        if not biomarker_key:
            return None

        # Get insights for this biomarker
        insights = BiomarkerService.BIOMARKER_INSIGHTS.get(biomarker_key, {})

        # Get the appropriate insight based on status
        status_key = status
        if status in ['critical_high', 'critical_low']:
            insight_data = insights.get(status, insights.get(status.replace('critical_', ''), {}))
        else:
            insight_data = insights.get(status, {})

        if not insight_data:
            # Generate generic insight if no specific one exists
            return BiomarkerService._generate_generic_insight(biomarker_name, value, status, reference_min, reference_max)

        # Get biomarker definition for additional context
        definition = BiomarkerService.get_biomarker_definition(biomarker_name)
        unit = definition.get('unit', '') if definition else ''

        # Calculate how far outside range
        deviation = None
        if status in ['high', 'critical_high'] and reference_max:
            deviation = ((value - reference_max) / reference_max) * 100
        elif status in ['low', 'critical_low'] and reference_min:
            deviation = ((reference_min - value) / reference_min) * 100

        # Build the insight object
        insight = {
            'id': f'insight_{biomarker_key}_{status}',
            'biomarkerName': biomarker_name,
            'biomarkerKey': biomarker_key,
            'value': value,
            'unit': unit,
            'status': status,
            'title': insight_data.get('title', f'{biomarker_name} is {status}'),
            'description': insight_data.get('description', ''),
            'severity': insight_data.get('severity', 'info'),
            'urgency': insight_data.get('urgency', 'routine'),
            'deviation': round(deviation, 1) if deviation else None,
            'referenceRange': {
                'min': reference_min,
                'max': reference_max
            },
            'actions': insight_data.get('actions', []),
            'doctorNeeded': insight_data.get('doctor_needed', False),
            'doctorReason': insight_data.get('doctor_reason', ''),
            'relatedTests': insight_data.get('related_tests', []),
            'timeframe': insight_data.get('timeframe', ''),
            'trendDirection': trend_direction,
            'trendContext': BiomarkerService._get_trend_context(biomarker_key, trend_direction),
        }

        return insight

    @staticmethod
    def _get_trend_context(biomarker_key: str, trend_direction: str) -> str:
        """Generate context about what the trend means for this biomarker"""
        if not trend_direction or trend_direction == 'insufficient_data':
            return ''

        # Biomarkers where lower is better
        lower_is_better = ['total_cholesterol', 'ldl_cholesterol', 'triglycerides', 'glucose',
                          'fasting_glucose', 'hba1c', 'alt', 'ast', 'creatinine', 'bun',
                          'crp', 'systolic_blood_pressure', 'diastolic_blood_pressure']

        # Biomarkers where higher is better
        higher_is_better = ['hdl_cholesterol', 'vitamin_d', 'vitamin_b12', 'hemoglobin', 'ferritin', 'spo2']

        if trend_direction == 'improving':
            if biomarker_key in lower_is_better:
                return 'Good news! Your levels are trending downward, which is the healthy direction for this marker.'
            elif biomarker_key in higher_is_better:
                return 'Good news! Your levels are trending upward, which is the healthy direction for this marker.'
            else:
                return 'Your levels appear to be moving in a healthier direction.'
        elif trend_direction == 'declining':
            if biomarker_key in lower_is_better:
                return 'Your levels are increasing over time. Consider discussing this trend with your doctor.'
            elif biomarker_key in higher_is_better:
                return 'Your levels are decreasing over time. This may need attention.'
            else:
                return 'Your levels are showing a declining trend that may need monitoring.'
        elif trend_direction == 'stable':
            return 'Your levels have remained relatively stable over time.'

        return ''

    @staticmethod
    def _generate_generic_insight(biomarker_name: str, value: float, status: str,
                                   reference_min: float = None, reference_max: float = None) -> Dict:
        """Generate a generic insight when no specific insight is defined"""
        definition = BiomarkerService.get_biomarker_definition(biomarker_name)

        if status == 'normal':
            return {
                'id': f'insight_{biomarker_name.lower().replace(" ", "_")}_normal',
                'biomarkerName': biomarker_name,
                'status': 'normal',
                'title': f'{biomarker_name} is Within Normal Range',
                'description': f'Your {biomarker_name} level of {value} is within the normal reference range.',
                'severity': 'success',
                'urgency': 'none',
                'actions': ['Continue your current healthy habits', 'Monitor at your next routine check-up'],
                'doctorNeeded': False,
                'doctorReason': '',
            }

        severity_map = {
            'high': 'warning',
            'low': 'warning',
            'critical_high': 'critical',
            'critical_low': 'critical'
        }

        direction = 'elevated' if 'high' in status else 'below normal'

        return {
            'id': f'insight_{biomarker_name.lower().replace(" ", "_")}_{status}',
            'biomarkerName': biomarker_name,
            'value': value,
            'status': status,
            'title': f'{biomarker_name} is {direction.title()}',
            'description': f'Your {biomarker_name} level of {value} is {direction}. ' +
                          (definition.get('clinical_significance', '') if definition else ''),
            'severity': severity_map.get(status, 'info'),
            'urgency': 'soon' if 'critical' in status else 'routine',
            'referenceRange': {
                'min': reference_min,
                'max': reference_max
            },
            'actions': [
                'Discuss this result with your healthcare provider',
                'Review any medications or supplements you are taking',
                'Consider lifestyle factors that may influence this marker'
            ],
            'doctorNeeded': True,
            'doctorReason': 'Your doctor can help determine the cause and appropriate next steps.',
        }

    @staticmethod
    def get_all_health_insights(user, active_only: bool = True) -> List[Dict]:
        """
        Generate all health insights for a user based on their biomarker data.
        Returns a prioritized list of insights.
        """
        insights = []

        # Get all biomarkers with trends
        biomarkers_data = BiomarkerService.get_user_biomarkers_with_trends(user, only_with_data=True)

        for biomarker_data in biomarkers_data:
            definition = biomarker_data.get('definition', {})
            latest_obs = biomarker_data.get('latestObservation')

            if not latest_obs:
                continue

            # Get status
            status = latest_obs.get('status', 'unknown')

            # Skip normal values if active_only
            if active_only and status == 'normal':
                continue

            # Generate insight
            insight = BiomarkerService.generate_health_insight(
                biomarker_name=definition.get('name', latest_obs.get('analyteName', '')),
                value=latest_obs.get('valueNum', latest_obs.get('value')),
                status=status,
                reference_min=latest_obs.get('refLow'),
                reference_max=latest_obs.get('refHigh'),
                trend_direction=biomarker_data.get('trendDirection')
            )

            if insight:
                # Add observation details
                insight['collectedAt'] = latest_obs.get('collectedAt')
                insight['observationCount'] = biomarker_data.get('totalObservations', 0)
                insights.append(insight)

        # Sort by severity (critical first) and then by urgency
        severity_order = {'critical': 0, 'warning': 1, 'info': 2, 'success': 3}
        urgency_order = {'urgent': 0, 'soon': 1, 'routine': 2, 'none': 3}

        insights.sort(key=lambda x: (
            severity_order.get(x.get('severity'), 9),
            urgency_order.get(x.get('urgency'), 9)
        ))

        return insights
