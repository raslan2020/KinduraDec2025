pdf_to_markdown_prompt = """
You are an agent that can extract data from a PDF file and return a JSON object.

The PDF file is a patient summary of a course of medicines.

The JSON object should have the following fields:

- name: The name of the course
- start_date: The start date of the course
- duration: The duration of the course in days
- patient_history: The patient's history
- current_situation: The current situation of the patient
- doctor_instructions: The instructions from the doctor
- medicines_and_schedules: A list of medicines and their schedules

The JSON object should be in the following format:

{
  "name": "Post-Surgical Antibiotic Regimen",
  "start_date": "2025-06-25",
  "duration": 10,
  "patient_history": "Patient underwent laparoscopic appendectomy. \\n No complications during surgery. \\n History of seasonal allergies but no drug allergies. \\n Previous use of azithromycin caused no adverse effects.",
  "current_situation": "Patient is in postoperative recovery. \\n Experiencing mild abdominal discomfort and low-grade fever (37.9°C). \\n Surgical site is clean with no signs of infection. \\n Blood pressure stable, mild fatigue reported.",
  "doctor_instructions": "Take medications with food to avoid gastric irritation. \\n Complete the antibiotic course. \\n Avoid strenuous activity for 1 week. \\n Monitor incision for redness or discharge. \\n Contact doctor if fever exceeds 38.5°C.",
  "medicines_and_schedules": [
    {
      "medicine_name": "Ciprofloxacin",
      "medicine_description": "Antibiotic to prevent post-surgical infection",
      "time": "09:00:00",
      "dosage": "250mg"
    },
    {
      "medicine_name": "Ciprofloxacin",
      "medicine_description": "Antibiotic to prevent post-surgical infection",
      "time": "21:00:00",
      "dosage": "250mg"
    },
    {
      "medicine_name": "Paracetamol",
      "medicine_description": "Pain reliever and fever reducer",
      "time": "13:00:00",
      "dosage": "500mg"
    },
    {
      "medicine_name": "Zinc Sulfate",
      "medicine_description": "Supports wound healing and immune function",
      "time": "10:00:00",
      "dosage": "20mg"
    }
  ]
}


Instructions:
- Extract the data from the PDF file
- Return the JSON object
- The JSON object should be in the correct format
- The JSON object should be valid
- The JSON object should be complete
- The JSON object should be accurate
- Dont mention the instructions in the JSON object
- if the patient_history, current_situation and doctor_instructions are in bullot point format, then use \\n to separate the points.
"""


summarize_patient_report_prompt = """
You are an agent that can summarize a patient and agent conservation. A json of conversation is provided to you in which the patient and agent are talking to each other and also the patient's course details are provided to you.

you need to extract following things from the particiapnt and agent conversation:

1. Is there any symptom that the patient is experiencing?
2. Is there any other issue that the patient is facing?
3. Sleeping pattern of the patient
4. Extract which medicine the patient is taking and the dosage.
5. The Content of the conversation between the patient and the agent should be in more detail.
6. How the patient is feeling after taking the medicine?


Your output should be in the following format:
{
    "conservation_summary": "The summary of the conversation between the patient and the agent like symptoms, other issues, sleeping pattern, medicines, etc.",
    "course_details": {
    "course": 5 # Id of the course
    "medicine": 3 # Id of the medicine
    "date": "2025-06-25" # Date of the medicine
    "time": "09:00:00" # Time of the medicine
    "taken": true # true if the patient has taken the medicine, otherwise false
    "summary": "Felt good after taking medicine. Blood sugar levels normal." # Summary of the medicine
    }
}

if the patient has taken the medicine, then the taken field should be true, otherwise it should be false.

Instructions:
- Extract the data from the conversation and the course details
- Return the JSON object
- The JSON object should be in the correct format
- The JSON object should be valid
- The JSON object should be complete
- The JSON object should be accurate
- Dont mention the instructions in the JSON object
"""