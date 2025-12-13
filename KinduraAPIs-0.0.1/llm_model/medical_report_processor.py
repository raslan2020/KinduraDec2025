import json
import re
from typing import Dict, List, Any, Optional
from datetime import datetime
import pymupdf
from .gpt_model import GPTModel

# Optional imports for image processing
try:
    from PIL import Image
    import pytesseract
    IMAGE_PROCESSING_AVAILABLE = True
except ImportError:
    IMAGE_PROCESSING_AVAILABLE = False


class MedicalReportProcessor:
    """
    Process medical reports (PDF/images) to extract structured medical information
    Uses LLM to intelligently parse and extract:
    - Biomarkers and lab values
    - Doctor's notes and recommendations
    - Medication changes
    - Diagnoses
    - Historical records
    """

    def __init__(self):
        self.gpt_model = GPTModel(model="gpt-4o")

    def extract_text_from_pdf(self, pdf_path: str) -> str:
        """Extract text from PDF file"""
        try:
            doc = pymupdf.open(pdf_path)
            text = ""

            for page in doc:
                text += page.get_text("text") + "\n\n"

            doc.close()
            return text.strip()
        except Exception as e:
            raise Exception(f"Error extracting text from PDF: {str(e)}")

    def extract_text_from_image(self, image_path: str) -> str:
        """Extract text from image using OCR"""
        if not IMAGE_PROCESSING_AVAILABLE:
            raise Exception("Image processing not available. Please install Pillow and pytesseract.")

        try:
            image = Image.open(image_path)
            text = pytesseract.image_to_string(image)
            return text.strip()
        except Exception as e:
            raise Exception(f"Error extracting text from image: {str(e)}")

    def extract_structured_data(self, text: str, user_current_medications: List[Dict] = None) -> Dict[str, Any]:
        """
        Use LLM to extract structured medical data from report text

        Args:
            text: Raw text from medical report
            user_current_medications: List of user's current medications for comparison

        Returns:
            Dictionary with structured medical data
        """

        # Build current medications context
        medications_context = ""
        if user_current_medications:
            medications_context = "\n\nPatient's current medications:\n"
            for med in user_current_medications:
                medications_context += f"- {med.get('drug_name')} {med.get('strength')}{med.get('strength_unit')}: "
                medications_context += f"{med.get('instructions_text', 'N/A')}\n"

        prompt = f"""You are a medical AI assistant analyzing a medical report. Extract ALL relevant information and return it as structured JSON.

Medical Report Text:
{text}
{medications_context}

Please extract and structure the following information:

1. BIOMARKERS AND LAB VALUES: Extract ALL lab test results - this is critical.

   ADAPTIVE DATA EXTRACTION - Handle ANY report format:

   A) SINGLE TEST REPORTS (most common):
      - One value per biomarker with one test date
      - Example: "Glucose: 95 mg/dL" tested on "2025-01-15"
      - Extract as: {{"name": "Glucose", "value": 95, "unit": "mg/dL", "test_date": "2025-01-15"}}

   B) TABULAR/TIME-SERIES DATA (multiple readings over time):
      - Data in rows with multiple date/time columns
      - Could be: daily, weekly, monthly, quarterly, or yearly readings
      - EXTRACT EACH VALUE AS A SEPARATE ENTRY
      - Examples of time columns to detect:
        * Months: Jan, Feb, Mar, January, February, etc.
        * Dates: 01/15, 2025-01-15, 15-Jan-2025, etc.
        * Weeks: Week 1, W1, Week of 01/01, etc.
        * Quarters: Q1, Q2, Q1 2025, etc.
        * Years: 2023, 2024, 2025, etc.

   C) MULTIPLE TESTS ON SAME DATE:
      - Many different biomarkers tested on one date
      - Extract each biomarker as separate entry with same date

   D) COMPARATIVE REPORTS (current vs previous):
      - Shows current and previous values side by side
      - Extract BOTH values with their respective dates

   For each reading extract:
   - name (STANDARDIZE names: "Fasting Glucose" not "FBS", "LDL Cholesterol" not "LDL",
           "Hemoglobin A1c" not "HbA1c", "White Blood Cell Count" not "WBC")
   - value (numeric value only, no text)
   - unit (measurement unit - standardize: mg/dL, g/dL, %, mmol/L, U/L, etc.)
   - reference_min and reference_max (if provided in report)
   - flag ("H" for high, "L" for low, "N" for normal, null if not specified)
   - test_date (YYYY-MM-DD format)

   DATE HANDLING - Be intelligent:
   * Look for year in document title, header, footer, or context
   * For month-only columns (Jan, Feb, etc.), use mid-month: YYYY-MM-15
   * For week numbers, calculate approximate date
   * For quarters, use mid-quarter: Q1=02-15, Q2=05-15, Q3=08-15, Q4=11-15
   * If date unclear, use report_date or collection date from document
   * NEVER use future dates - if result is future, subtract 1 year
   * If no date found at all, use null (will default to today)

2. MEDICATION RECOMMENDATIONS: Compare with current medications and identify:
   - New medications to start
   - Dosage changes
   - Schedule/frequency changes
   - Medications to discontinue

   For each recommendation include:
   - medication_name
   - brand_name (if mentioned)
   - change_type (one of: "new", "dosage_change", "schedule_change", "frequency_change", "discontinue")
   - old_value (current medication details as dict, null if new medication)
   - new_value (new medication details as dict with: dosage, strength, unit, frequency, schedule, duration)
   - reason (doctor's reason for the change)
   - is_urgent (true/false)
   - priority (0-10, higher = more important)

3. DOCTOR'S NOTES: Extract doctor's comments, observations, and general recommendations

4. DIAGNOSES: List of any diagnoses mentioned in the report

5. METADATA: Extract:
   - report_date (date of the report)
   - provider_name (doctor's name who ordered or reviewed the report)
   - facility_name (hospital/clinic name where patient was seen)
   - laboratory_name (lab where tests were performed - may be different from facility)

   IMPORTANT: Look for lab names in:
   - Header/letterhead (e.g., "Quest Diagnostics", "LabCorp", "PathGroup")
   - Footer with lab address
   - "Performed at:" or "Laboratory:" sections
   - "Accession #" or "Lab ID" sections often have lab name nearby
   - If lab name is same as facility, use the facility name

Return ONLY valid JSON in this exact format:
{{
    "biomarkers": [
        {{
            "name": "string",
            "value": float,
            "unit": "string",
            "reference_min": float or null,
            "reference_max": float or null,
            "flag": "H" or "L" or "N" or null,
            "test_date": "YYYY-MM-DD"
        }}
    ],
    "medication_recommendations": [
        {{
            "medication_name": "string",
            "brand_name": "string or null",
            "change_type": "new|dosage_change|schedule_change|frequency_change|discontinue",
            "old_value": {{"dosage": "string", "frequency": "string"}} or null,
            "new_value": {{"dosage": "string", "strength": number, "unit": "mg|g|ml|mcg", "frequency": "string", "schedule": "string", "duration": "string"}},
            "reason": "string",
            "is_urgent": boolean,
            "priority": number
        }}
    ],
    "doctor_notes": "string (all doctor's notes combined)",
    "diagnoses": ["diagnosis1", "diagnosis2"],
    "report_date": "YYYY-MM-DD" or null,
    "provider_name": "string or null",
    "facility_name": "string or null",
    "laboratory_name": "string or null"
}}

CRITICAL RULES:

1. EXTRACT EVERY DATA POINT: If a report has multiple values (time-series, comparative, etc.),
   create a SEPARATE biomarker entry for EACH value. Never aggregate or summarize.

2. BLOOD PRESSURE HANDLING: Always split compound BP readings:
   - "138/90 mmHg" becomes TWO entries:
     * {{"name": "Systolic Blood Pressure", "value": 138, "unit": "mmHg", ...}}
     * {{"name": "Diastolic Blood Pressure", "value": 90, "unit": "mmHg", ...}}

3. STANDARDIZE BIOMARKER NAMES (always use full descriptive names):
   - FBS, FBG → "Fasting Glucose"
   - LDL, LDL-C → "LDL Cholesterol"
   - HDL, HDL-C → "HDL Cholesterol"
   - TG, Trig → "Triglycerides"
   - HbA1c, A1C → "Hemoglobin A1c"
   - WBC → "White Blood Cell Count"
   - RBC → "Red Blood Cell Count"
   - Hgb, Hb → "Hemoglobin"
   - PLT → "Platelet Count"
   - ALT, SGPT → "Alanine Aminotransferase"
   - AST, SGOT → "Aspartate Aminotransferase"
   - Cr → "Creatinine"
   - BUN → "Blood Urea Nitrogen"
   - TSH → "Thyroid Stimulating Hormone"
   - CRP, hs-CRP → "C-Reactive Protein"
   - Vit D, 25-OH-D → "Vitamin D"
   - B12 → "Vitamin B12"
   - HR → "Heart Rate"
   - HRV → "Heart Rate Variability"
   - SpO2, O2 Sat → "Oxygen Saturation"

4. UNITS: Use standard medical units (mg/dL, g/dL, %, mmol/L, U/L, mIU/L, ng/mL, pg/mL, bpm, mmHg, ms)

5. For medication changes, carefully compare with current medications list provided

6. If no information found for a category, return empty list [] or null

7. All dates MUST be in YYYY-MM-DD format

8. Return ONLY valid JSON - no markdown, no comments, no explanations
"""

        try:
            messages = [
                {"role": "system", "content": "You are a medical AI assistant that extracts structured data from medical reports. Always return valid JSON."},
                {"role": "user", "content": prompt}
            ]

            response = self.gpt_model.chat(messages, temperature=0.3)

            if not response:
                raise Exception("No response from LLM")

            # Parse JSON response
            structured_data = json.loads(response)

            # Validate and clean data
            return self._validate_and_clean_data(structured_data)

        except json.JSONDecodeError as e:
            raise Exception(f"Failed to parse LLM response as JSON: {str(e)}")
        except Exception as e:
            raise Exception(f"Error extracting structured data: {str(e)}")

    def _validate_and_clean_data(self, data: Dict) -> Dict:
        """Validate and clean extracted data"""

        # Ensure required keys exist
        cleaned = {
            'biomarkers': data.get('biomarkers', []),
            'medication_recommendations': data.get('medication_recommendations', []),
            'doctor_notes': data.get('doctor_notes', ''),
            'diagnoses': data.get('diagnoses', []),
            'report_date': data.get('report_date'),
            'provider_name': data.get('provider_name'),
            'facility_name': data.get('facility_name'),
            'laboratory_name': data.get('laboratory_name'),
        }

        # Validate biomarkers
        for biomarker in cleaned['biomarkers']:
            if 'test_date' in biomarker:
                # Validate date format and check for future dates
                try:
                    test_date = datetime.strptime(biomarker['test_date'], '%Y-%m-%d')
                    today = datetime.now()

                    # If date is in the future, it's likely a year parsing error
                    if test_date > today:
                        # Subtract 1 year as it's probably using current year instead of last year
                        corrected_date = test_date.replace(year=test_date.year - 1)
                        biomarker['test_date'] = corrected_date.strftime('%Y-%m-%d')
                        print(f"⚠️  Corrected future date {test_date.date()} to {corrected_date.date()} for {biomarker.get('name', 'unknown')}")
                except:
                    biomarker['test_date'] = None

        # Validate medication recommendations
        for rec in cleaned['medication_recommendations']:
            # Ensure change_type is valid
            valid_types = ['new', 'dosage_change', 'schedule_change', 'frequency_change', 'discontinue']
            if rec.get('change_type') not in valid_types:
                rec['change_type'] = 'new'

            # Ensure priority is in range
            if 'priority' in rec:
                rec['priority'] = max(0, min(10, rec.get('priority', 0)))
            else:
                rec['priority'] = 5

            # Ensure is_urgent is boolean
            if 'is_urgent' not in rec:
                rec['is_urgent'] = False

        # Validate report date
        if cleaned.get('report_date'):
            try:
                datetime.strptime(cleaned['report_date'], '%Y-%m-%d')
            except:
                cleaned['report_date'] = None

        return cleaned

    def process_report(
        self,
        file_path: str,
        file_type: str,
        user_current_medications: List[Dict] = None
    ) -> Dict[str, Any]:
        """
        Main method to process a medical report

        Args:
            file_path: Path to the report file
            file_type: 'pdf' or 'image'
            user_current_medications: User's current medications for comparison

        Returns:
            Dictionary with extracted text and structured data
        """

        # Extract text
        if file_type.lower() == 'pdf' or file_path.lower().endswith('.pdf'):
            extracted_text = self.extract_text_from_pdf(file_path)
        else:
            extracted_text = self.extract_text_from_image(file_path)

        if not extracted_text or len(extracted_text.strip()) < 50:
            raise Exception("Insufficient text extracted from document")

        # Extract structured data using LLM
        structured_data = self.extract_structured_data(extracted_text, user_current_medications)

        return {
            'extracted_text': extracted_text,
            'structured_data': structured_data
        }


def process_medical_report(file_path: str, file_type: str, user_medications: List[Dict] = None) -> Dict[str, Any]:
    """
    Convenience function to process a medical report

    Usage:
        result = process_medical_report('path/to/report.pdf', 'pdf', user_meds)
        print(result['extracted_text'])
        print(result['structured_data']['biomarkers'])
        print(result['structured_data']['medication_recommendations'])
    """
    processor = MedicalReportProcessor()
    return processor.process_report(file_path, file_type, user_medications)
