# Kindura Clinical Reports & Data Framework
**Version:** 4.0  
**Domain:** Parkinson’s Disease & General Health Monitoring  
**Classification:** Clinical Decision Support (Non-Diagnostic, Non-Prescriptive)  
**Primary Audience:** Neurologists, Movement Disorder Specialists  
**Secondary Audience:** AI Agents, Developers

---

## 1. Clinical Purpose & Design Principles

Kindura is a **longitudinal clinical documentation and decision-support system** designed to mirror how neurologists evaluate Parkinson’s disease in routine and follow-up visits.

The system:
- Structures patient-reported, caregiver-reported, and device-derived data
- Reconstructs interim clinical history between visits
- Highlights trends, correlations, and risks
- Produces physician-ready reports resembling real clinic notes

Kindura **does not diagnose, prescribe, or replace clinician judgment**.

---

## 2. Report Types & Clinical Intent

### 2.1 Baseline Clinical & Diagnostic Assessment
Generated at onboarding or when Parkinson’s is suspected.

Purpose:
- Establish a comprehensive baseline
- Support differential diagnosis
- Document symptom onset, progression, and context
- Serve as reference for all future comparisons

---

### 2.2 Daily Clinical Snapshot
Short, low-burden log used to **accumulate granular longitudinal data**, not for interpretation.

---

### 2.3 Weekly Interim Clinical Report
A **mini follow-up visit summary**, reconstructing what the clinician would ask:
> “What changed since last week?”

---

### 2.4 Monthly Comprehensive Physician Report
A **full Parkinson’s follow-up visit note**, suitable for EMR attachment or pre-visit review.

---

## 3. Core Data Domains (Collected Across Reports)

- Medical history
- Neurological symptoms (motor & non-motor)
- General health and function
- Psychological and cognitive status
- Lifestyle and habits
- Medication use and adherence
- Labs and diagnostics
- Objective sensor data
- Safety events
- Patient goals and concerns
- AI-generated clinical considerations

---

# BASELINE REPORT (REFERENCE)

## 4. Baseline Clinical & Diagnostic Assessment

### 4.1 Reason for Evaluation
- Primary symptoms prompting evaluation
- Patient-described concerns
- Caregiver concerns (if any)

---

### 4.2 Symptom Onset & Timeline
- First symptom noted (type, date)
- Initial laterality
- Progression pattern (slow, stepwise, fluctuating)
- Triggers or modifiers (stress, sleep, medication)

---

### 4.3 Medical & Family History
- Comorbidities
- Neurological history
- Psychiatric history
- Family history of Parkinson’s, tremor, dementia

---

### 4.4 Baseline Neurological Symptom Inventory
**Motor**
- Bradykinesia
- Tremor (rest vs action)
- Rigidity
- Gait and balance
- Freezing episodes

**Non-Motor**
- Sleep / REM behavior
- Constipation
- Autonomic symptoms
- Mood and anxiety
- Cognitive complaints
- Pain and fatigue
- Hallucinations (if present)

---

### 4.5 Baseline Functional Status
- Activities of daily living (ADLs)
- Work or home function
- Falls history
- Speech and swallowing

---

### 4.6 Baseline Medications
- Current medications
- Past Parkinson’s therapies and response
- Side effects history

---

### 4.7 Baseline Labs & Imaging
- Relevant laboratory summaries
- Imaging summaries (MRI, DaTscan)

---

### 4.8 Initial AI Clinical Summary (Non-Diagnostic)
- Core motor features present / absent
- Symmetry vs asymmetry
- Progression pattern
- Red flags screening

---

# DAILY REPORT

## 5. Daily Clinical Snapshot

### 5.1 Core Symptoms (1–5 Scale)
- Bradykinesia
- Tremor
- Rigidity
- Gait difficulty

---

### 5.2 Non-Motor Snapshot
- Mood
- Sleep quality
- Fatigue
- Pain

---

### 5.3 Medication Log
- Scheduled doses
- Taken / missed
- Delay (minutes)
- Immediate side effects

---

### 5.4 Activity & Health Signals
- Step count
- Falls (yes/no)
- Resting HR
- HRV (if available)

---

# WEEKLY REPORT (DETAILED)

## 6. Weekly Interim Clinical Report

### 6.1 Interval History (Since Last Report)
- Patient’s overall impression of the week
- New or worsening symptoms
- Improved symptoms
- Notable events (falls, illness, stressors)

---

### 6.2 Motor Symptom Trends
For each symptom:
- Average severity
- Best vs worst day
- Time-of-day patterns
- Laterality changes

**Motor domains**
- Bradykinesia
- Tremor
- Rigidity
- Gait / balance

---

### 6.3 Non-Motor Symptom Review
- Sleep changes
- Mood fluctuations
- Autonomic symptoms
- Fatigue and pain
- Hallucinations or vivid dreams

---

### 6.4 Medication Adherence & Response
- % doses taken on time
- Missed or delayed doses
- Symptom response post-dose
- Wearing-off patterns
- Side effects observed

---

### 6.5 Functional Impact
- Mobility confidence
- ADL interference
- Falls or near-falls
- Speech or swallowing concerns

---

### 6.6 Lifestyle & Behavioral Factors
- Sleep schedule consistency
- Physical activity level
- Sedentary time
- Sun exposure
- Notable dietary or hydration issues

---

### 6.7 Objective Data Summary
- Step count trends
- Gait variability
- Tremor detection frequency
- HR / HRV trends

---

### 6.8 Safety & Red Flags
- Falls
- Rapid symptom worsening
- Cognitive or psychiatric red flags

---

### 6.9 Weekly AI Clinical Observations (For Review)
- Correlations between medication timing and symptoms
- Emerging patterns
- Data quality assessment

---

# MONTHLY REPORT (VERY DETAILED – CLINIC VISIT LEVEL)

## 7. Monthly Comprehensive Physician Report

### 7.1 Chief Complaint / Visit Focus
- Primary issues since last visit
- Patient priorities and goals
- Caregiver concerns

---

### 7.2 Interim History (Last 4–6 Weeks)
- Overall disease trajectory
- Motor symptom progression
- Non-motor symptom evolution
- Major events (falls, hospitalizations, infections)

---

### 7.3 Detailed Motor Assessment
For each domain:
- Baseline vs current severity
- Trend direction
- Variability
- Laterality changes

**Motor domains**
- Bradykinesia
- Tremor
- Rigidity
- Gait and balance
- Freezing

---

### 7.4 Detailed Non-Motor Assessment
- Sleep and REM behavior
- Mood (PHQ-9 trend)
- Anxiety and apathy
- Autonomic symptoms
- Cognitive complaints
- Pain and fatigue

---

### 7.5 Functional & Quality-of-Life Assessment
- ADLs
- Mobility independence
- Falls risk
- Speech and swallowing
- Social and occupational impact

---

### 7.6 Medication Review
- Current regimen
- Adherence consistency
- Wearing-off or ON/OFF patterns
- Side effects
- Historical response comparison

---

### 7.7 Lifestyle & Habits Review
- Sleep-wake rhythm
- Physical activity adequacy
- Sun exposure
- Behavioral contributors to symptoms

---

### 7.8 Laboratory & Diagnostic Review
- New labs since last visit
- Notable trends
- Imaging updates

---

### 7.9 Objective Data Interpretation (Supportive)
- Activity and gait trends
- Tremor frequency
- Physiologic stress indicators

---

### 7.10 AI-Generated Clinical Considerations (Physician Review Only)
- Pattern summaries
- Medication timing considerations
- Risk flags
- Data confidence level

---

### 7.11 Physician Assessment & Plan (Blank Section)
- Clinical assessment
- Medication decisions
- Referrals (PT, speech, psych)
- Follow-up interval

---

## 8. AI Governance & Safety

### 8.1 AI Boundaries
AI may:
- Detect patterns
- Correlate variables
- Summarize trends

AI may not:
- Diagnose
- Prescribe
- Recommend dosages
- Direct patient treatment

---

### 8.2 Mandatory Disclaimer
> “This report is generated from self-reported and device-derived data and is intended to support, not replace, clinical judgment.”

---

## 9. Internal Validation & Quality Control (Silent)
- Bradykinesia assessed
- Laterality captured
- Medication timing correlated
- Red flags escalated
- Evidence sources tagged

Failure → downgrade report confidence.

---

## 10. Clinical Value Statement

This reporting framework is designed to:
- Mirror real Parkinson’s clinic documentation
- Improve visit efficiency
- Enhance longitudinal insight
- Support safer, better-informed clinical decisions

This document is the **single source of truth** for all Kindura clinical reports.
