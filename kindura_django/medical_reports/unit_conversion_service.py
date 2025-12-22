"""
Unit Conversion Service for Medical Biomarkers
Handles conversion between US Standard and International SI units
"""
from typing import Dict, Tuple, Optional, List
from decimal import Decimal, ROUND_HALF_UP


class UnitConversionService:
    """
    Service for converting biomarker values between unit systems.

    Supports:
    - US Standard: mg/dL, lbs, °F, etc.
    - SI (International): mmol/L, kg, °C, etc.
    """

    # Unit conversion definitions for common biomarkers
    # Format: 'biomarker_key': {
    #     'us_unit': 'unit string',
    #     'si_unit': 'unit string',
    #     'us_to_si': conversion_factor (multiply US by this to get SI),
    #     'si_to_us': conversion_factor (multiply SI by this to get US),
    #     'decimals': number of decimal places for display
    # }
    CONVERSIONS = {
        # Glucose and Sugars
        'glucose': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.0555,  # mg/dL to mmol/L
            'si_to_us': 18.0182,  # mmol/L to mg/dL
            'decimals': 1
        },
        'fasting_glucose': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.0555,
            'si_to_us': 18.0182,
            'decimals': 1
        },

        # Lipid Panel
        'total_cholesterol': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.0259,  # mg/dL to mmol/L for cholesterol
            'si_to_us': 38.67,
            'decimals': 2
        },
        'ldl_cholesterol': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.0259,
            'si_to_us': 38.67,
            'decimals': 2
        },
        'hdl_cholesterol': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.0259,
            'si_to_us': 38.67,
            'decimals': 2
        },
        'triglycerides': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.0113,  # Different conversion for triglycerides
            'si_to_us': 88.57,
            'decimals': 2
        },

        # Kidney Function
        'creatinine': {
            'us_unit': 'mg/dL',
            'si_unit': 'µmol/L',
            'us_to_si': 88.4,  # mg/dL to µmol/L
            'si_to_us': 0.0113,
            'decimals': 0
        },
        'bun': {
            'us_unit': 'mg/dL',
            'si_unit': 'mmol/L',
            'us_to_si': 0.357,  # BUN mg/dL to mmol/L
            'si_to_us': 2.801,
            'decimals': 1
        },

        # Liver Function (no conversion needed - same units)
        'alt': {
            'us_unit': 'U/L',
            'si_unit': 'U/L',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },
        'ast': {
            'us_unit': 'U/L',
            'si_unit': 'U/L',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },

        # Diabetes
        'hba1c': {
            'us_unit': '%',
            'si_unit': 'mmol/mol',
            'us_to_si': lambda x: (x - 2.15) * 10.929,  # NGSP to IFCC
            'si_to_us': lambda x: (x / 10.929) + 2.15,  # IFCC to NGSP
            'decimals': 1,
            'is_formula': True
        },

        # Thyroid
        'tsh': {
            'us_unit': 'mIU/L',
            'si_unit': 'mIU/L',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 2
        },

        # Inflammation
        'crp': {
            'us_unit': 'mg/L',
            'si_unit': 'mg/L',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 1
        },

        # Vitamins
        'vitamin_d': {
            'us_unit': 'ng/mL',
            'si_unit': 'nmol/L',
            'us_to_si': 2.496,  # ng/mL to nmol/L
            'si_to_us': 0.4006,
            'decimals': 1
        },
        'vitamin_b12': {
            'us_unit': 'pg/mL',
            'si_unit': 'pmol/L',
            'us_to_si': 0.738,  # pg/mL to pmol/L
            'si_to_us': 1.355,
            'decimals': 0
        },

        # Iron
        'ferritin': {
            'us_unit': 'ng/mL',
            'si_unit': 'µg/L',
            'us_to_si': 1.0,  # Same value, different notation
            'si_to_us': 1.0,
            'decimals': 0
        },

        # Hematology
        'hemoglobin': {
            'us_unit': 'g/dL',
            'si_unit': 'g/L',
            'us_to_si': 10.0,  # g/dL to g/L
            'si_to_us': 0.1,
            'decimals': 1
        },
        'wbc': {
            'us_unit': 'x10^3/µL',
            'si_unit': 'x10^9/L',
            'us_to_si': 1.0,  # Same value, different notation
            'si_to_us': 1.0,
            'decimals': 1
        },
        'rbc': {
            'us_unit': 'x10^6/µL',
            'si_unit': 'x10^12/L',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 2
        },
        'platelets': {
            'us_unit': 'x10^3/µL',
            'si_unit': 'x10^9/L',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },

        # Vital Signs
        'heart_rate': {
            'us_unit': 'bpm',
            'si_unit': 'bpm',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },
        'systolic_blood_pressure': {
            'us_unit': 'mmHg',
            'si_unit': 'mmHg',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },
        'diastolic_blood_pressure': {
            'us_unit': 'mmHg',
            'si_unit': 'mmHg',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },
        'spo2': {
            'us_unit': '%',
            'si_unit': '%',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },
        'hrv': {
            'us_unit': 'ms',
            'si_unit': 'ms',
            'us_to_si': 1.0,
            'si_to_us': 1.0,
            'decimals': 0
        },

        # Weight
        'weight': {
            'us_unit': 'lbs',
            'si_unit': 'kg',
            'us_to_si': 0.4536,  # lbs to kg
            'si_to_us': 2.2046,  # kg to lbs
            'decimals': 1
        },

        # Temperature
        'temperature': {
            'us_unit': '°F',
            'si_unit': '°C',
            'us_to_si': lambda x: (x - 32) * 5/9,  # °F to °C
            'si_to_us': lambda x: (x * 9/5) + 32,  # °C to °F
            'decimals': 1,
            'is_formula': True
        },
    }

    # Unit system definitions
    UNIT_SYSTEMS = {
        'US': 'US Standard (mg/dL, lbs, °F)',
        'SI': 'International SI (mmol/L, kg, °C)',
    }

    @classmethod
    def get_biomarker_key(cls, name: str) -> Optional[str]:
        """Normalize biomarker name to key"""
        name_lower = name.lower().strip()

        # Direct match
        if name_lower.replace(' ', '_') in cls.CONVERSIONS:
            return name_lower.replace(' ', '_')

        # Common mappings
        name_mappings = {
            'glucose': 'glucose',
            'fasting glucose': 'fasting_glucose',
            'ldl cholesterol': 'ldl_cholesterol',
            'hdl cholesterol': 'hdl_cholesterol',
            'ldl': 'ldl_cholesterol',
            'hdl': 'hdl_cholesterol',
            'triglycerides': 'triglycerides',
            'total cholesterol': 'total_cholesterol',
            'creatinine': 'creatinine',
            'bun': 'bun',
            'blood urea nitrogen': 'bun',
            'alt': 'alt',
            'alanine aminotransferase': 'alt',
            'ast': 'ast',
            'aspartate aminotransferase': 'ast',
            'hba1c': 'hba1c',
            'hemoglobin a1c': 'hba1c',
            'tsh': 'tsh',
            'thyroid stimulating hormone': 'tsh',
            'crp': 'crp',
            'c-reactive protein': 'crp',
            'vitamin d': 'vitamin_d',
            'vitamin b12': 'vitamin_b12',
            'b12': 'vitamin_b12',
            'ferritin': 'ferritin',
            'hemoglobin': 'hemoglobin',
            'wbc': 'wbc',
            'white blood cell count': 'wbc',
            'rbc': 'rbc',
            'red blood cell count': 'rbc',
            'platelets': 'platelets',
            'platelet count': 'platelets',
            'heart rate': 'heart_rate',
            'systolic blood pressure': 'systolic_blood_pressure',
            'diastolic blood pressure': 'diastolic_blood_pressure',
            'spo2': 'spo2',
            'oxygen saturation': 'spo2',
            'hrv': 'hrv',
            'heart rate variability': 'hrv',
            'weight': 'weight',
            'temperature': 'temperature',
        }

        return name_mappings.get(name_lower)

    @classmethod
    def convert_value(
        cls,
        value: float,
        biomarker_name: str,
        from_unit: str,
        to_system: str  # 'US' or 'SI'
    ) -> Tuple[float, str]:
        """
        Convert a biomarker value to the target unit system.

        Args:
            value: The numeric value to convert
            biomarker_name: Name of the biomarker
            from_unit: The current unit of the value
            to_system: Target unit system ('US' or 'SI')

        Returns:
            Tuple of (converted_value, new_unit)
        """
        biomarker_key = cls.get_biomarker_key(biomarker_name)

        if not biomarker_key or biomarker_key not in cls.CONVERSIONS:
            # No conversion available, return original
            return (value, from_unit)

        conversion = cls.CONVERSIONS[biomarker_key]
        target_unit = conversion['si_unit'] if to_system == 'SI' else conversion['us_unit']

        # Determine current unit system
        from_unit_lower = from_unit.lower().strip()
        us_unit_lower = conversion['us_unit'].lower()
        si_unit_lower = conversion['si_unit'].lower()

        # If already in target unit, no conversion needed
        if to_system == 'SI' and from_unit_lower == si_unit_lower:
            return (round(value, conversion['decimals']), conversion['si_unit'])
        if to_system == 'US' and from_unit_lower == us_unit_lower:
            return (round(value, conversion['decimals']), conversion['us_unit'])

        # Perform conversion
        if conversion.get('is_formula'):
            # Use formula-based conversion
            if to_system == 'SI':
                converter = conversion['us_to_si']
            else:
                converter = conversion['si_to_us']
            converted = converter(value)
        else:
            # Use factor-based conversion
            if to_system == 'SI':
                converted = value * conversion['us_to_si']
            else:
                converted = value * conversion['si_to_us']

        return (round(converted, conversion['decimals']), target_unit)

    @classmethod
    def convert_biomarker(
        cls,
        biomarker_data: Dict,
        to_system: str
    ) -> Dict:
        """
        Convert a biomarker dict to the target unit system.

        Args:
            biomarker_data: Dict with 'name', 'value', 'unit' keys
            to_system: Target unit system ('US' or 'SI')

        Returns:
            New dict with converted value and unit
        """
        name = biomarker_data.get('name', '')
        value = biomarker_data.get('value')
        unit = biomarker_data.get('unit', '')

        if value is None:
            return biomarker_data

        try:
            value = float(value)
        except (TypeError, ValueError):
            return biomarker_data

        converted_value, converted_unit = cls.convert_value(
            value, name, unit, to_system
        )

        # Create new dict with converted values
        result = biomarker_data.copy()
        result['value'] = converted_value
        result['unit'] = converted_unit
        result['original_value'] = biomarker_data.get('value')
        result['original_unit'] = unit

        return result

    @classmethod
    def convert_biomarkers_list(
        cls,
        biomarkers: List[Dict],
        to_system: str
    ) -> List[Dict]:
        """
        Convert a list of biomarkers to the target unit system.

        Args:
            biomarkers: List of biomarker dicts
            to_system: Target unit system ('US' or 'SI')

        Returns:
            List of converted biomarker dicts
        """
        return [cls.convert_biomarker(b, to_system) for b in biomarkers]

    @classmethod
    def get_preferred_unit(cls, biomarker_name: str, unit_system: str) -> Optional[str]:
        """Get the preferred unit for a biomarker in the specified system"""
        biomarker_key = cls.get_biomarker_key(biomarker_name)

        if not biomarker_key or biomarker_key not in cls.CONVERSIONS:
            return None

        conversion = cls.CONVERSIONS[biomarker_key]
        return conversion['si_unit'] if unit_system == 'SI' else conversion['us_unit']

    @classmethod
    def get_all_supported_biomarkers(cls) -> List[str]:
        """Get list of all biomarkers with conversion support"""
        return list(cls.CONVERSIONS.keys())
