# Kindura AI - Improvement Plan

**Generated**: 2025-11-29
**Status**: Comprehensive Analysis Complete

---

## Executive Summary

Kindura AI is a well-architected health/wellness app with 80% of core features implemented. Key gaps exist in:
1. **Patient Reports UI** (models exist, UI empty)
2. **Caregiver Management** (not implemented)
3. **Security Hardening** (custom tokens, no expiration)
4. **Testing** (no test coverage)

---

## Priority Matrix

### P0 - CRITICAL (Blocking Production)

| # | Issue | Impact | Effort | Files |
|---|-------|--------|--------|-------|
| 1 | **Kindura Reports Screen Empty** | Users can't see AI-generated reports | Medium | `lib/screens/kindura_reports/` |
| 2 | **Security: Token Never Expires** | Compromised tokens work forever | Low | `users/models.py`, `utils/authentication.py` |
| 3 | **Security: Hardcoded Secret Key Fallback** | Insecure if .env missing | Low | `settings.py` |
| 4 | **No Input Validation on Biomarkers** | Invalid data can be saved | Medium | `biomarker_views.py` |

### P1 - HIGH (Should Fix Soon)

| # | Issue | Impact | Effort | Files |
|---|-------|--------|--------|-------|
| 5 | **Caregiver Contact Management** | No emergency contacts | High | New screens needed |
| 6 | **Medication Recommendations UI** | Can't apply AI suggestions | Medium | `lib/screens/medication/` |
| 7 | **Side Effects History View** | Can't review past side effects | Medium | New screen needed |
| 8 | **Medication Interactions Checker** | No drug interaction warnings | High | `medicines/views.py` |
| 9 | **Insight Dismissal Not Persisted** | Dismissed insights return | Low | `biomarker_views.py` |

### P2 - MEDIUM (Nice to Have)

| # | Issue | Impact | Effort | Files |
|---|-------|--------|--------|-------|
| 10 | **Email/SMS Notifications** | No caregiver alerts | High | New service needed |
| 11 | **Conversation History Storage** | Agent forgets context | Medium | `agent.py` |
| 12 | **Real-time Medication Reminders** | Local notifications not triggered | Medium | `notification_service.dart` |
| 13 | **Offline Mode** | App needs internet | High | Throughout app |
| 14 | **FHIR Export** | Can't export data | Medium | `biomarker_views.py` |

### P3 - LOW (Future Enhancement)

| # | Issue | Impact | Effort | Files |
|---|-------|--------|--------|-------|
| 15 | Camera Document Scan | Must upload files | Low | `labs_screen.dart` |
| 16 | Multi-language Support | English only | High | Throughout app |
| 17 | Accessibility Features | Not accessible | High | Throughout app |
| 18 | Predictive Analytics | Basic analytics only | Very High | New service |

---

## Implementation Roadmap

### Sprint 1: Security & Reports (Week 1)

#### Task 1.1: Add Token Expiration
```python
# users/models.py - Add expires_at field to UserToken
class UserToken(models.Model):
    token = models.CharField(max_length=255, unique=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True, blank=True)  # NEW

# utils/authentication.py - Check expiration
def authenticate(self, request):
    token = self.get_token(request)
    if token:
        user_token = UserToken.objects.filter(token=token, is_active=True).first()
        if user_token:
            if user_token.expires_at and user_token.expires_at < timezone.now():
                raise AuthenticationFailed('Token expired')
            return (user_token.user, None)
    return None
```

#### Task 1.2: Remove Hardcoded Secret Key
```python
# settings.py - Fail if SECRET_KEY not in environment
SECRET_KEY = os.environ.get('SECRET_KEY')
if not SECRET_KEY:
    raise ImproperlyConfigured('SECRET_KEY environment variable is required')
```

#### Task 1.3: Implement Kindura Reports Screen
```dart
// lib/screens/kindura_reports/kindura_reports_screen.dart
// Load and display PatientReport objects
// - Daily reports with medication adherence
// - Weekly reports with trends
// - Monthly summaries for doctor
```

**Deliverables:**
- [ ] Token expiration (24 hours default)
- [ ] SECRET_KEY required
- [ ] Kindura Reports displays daily/weekly/monthly reports
- [ ] Report filtering by date range

---

### Sprint 2: Caregiver & Recommendations (Week 2)

#### Task 2.1: Caregiver Contact Management
```dart
// New screens:
// lib/screens/caregiver/caregiver_list_screen.dart
// lib/screens/caregiver/add_caregiver_screen.dart

// Model already exists in backend, need:
// - Flutter model
// - Repository
// - UI screens
```

#### Task 2.2: Medication Recommendations Display
```dart
// lib/screens/medication/medication_recommendations_screen.dart
// - Show AI-extracted recommendations from medical reports
// - Accept/Dismiss functionality
// - Apply to medication list
```

#### Task 2.3: Side Effects History
```dart
// lib/screens/side_effects/side_effects_history_screen.dart
// - List all reported side effects
// - Filter by medication
// - Show severity and date
```

**Deliverables:**
- [ ] Caregiver list screen
- [ ] Add/Edit caregiver screen
- [ ] Medication recommendations display
- [ ] Accept/Dismiss recommendation actions
- [ ] Side effects history view

---

### Sprint 3: Validation & Quality (Week 3)

#### Task 3.1: Input Validation
```python
# medical_reports/biomarker_views.py
def add_manual_observation(request):
    value = float(request.data.get('value'))

    # Validate against physiological ranges
    warning = BiomarkerService.validate_biomarker_value(
        biomarker_name, value, unit
    )
    if warning:
        return Response({
            'status': False,
            'warning': warning,
            'message': 'Value seems unusual. Please verify.'
        }, status=status.HTTP_400_BAD_REQUEST)
```

#### Task 3.2: Insight Dismissal Persistence
```python
# medical_reports/models.py - New model
class DismissedInsight(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    biomarker_name = models.CharField(max_length=255)
    insight_type = models.CharField(max_length=50)
    dismissed_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(null=True)  # Auto-restore after time
```

#### Task 3.3: Add Unit Tests
```python
# medical_reports/tests.py
class BiomarkerServiceTests(TestCase):
    def test_normalize_biomarker_name(self):
        self.assertEqual(
            BiomarkerService.normalize_biomarker_name('LDL-C'),
            'ldl_cholesterol'
        )

    def test_validate_biomarker_value_invalid(self):
        warning = BiomarkerService.validate_biomarker_value(
            'Glucose', 1000, 'mg/dL'  # Impossible value
        )
        self.assertIsNotNone(warning)
```

**Deliverables:**
- [ ] Biomarker value validation
- [ ] Dismissed insight persistence
- [ ] Unit tests for BiomarkerService
- [ ] Unit tests for UnitConversionService
- [ ] Integration tests for key API endpoints

---

### Sprint 4: Notifications & Interactions (Week 4)

#### Task 4.1: Local Medication Reminders
```dart
// lib/services/notification_service.dart
Future<void> scheduleMedicationReminder(
  Medicine medication,
  DateTime scheduledTime,
  int reminderMinutesBefore,
) async {
  await _notifications.zonedSchedule(
    medication.id,
    'Medication Reminder',
    'Time to take ${medication.drugName}',
    tz.TZDateTime.from(scheduledTime.subtract(
      Duration(minutes: reminderMinutesBefore)
    ), tz.local),
    // ...
  );
}
```

#### Task 4.2: Drug Interaction Checker
```python
# medicines/views.py
@action(detail=False, methods=['post'])
def check_interactions(self, request):
    """Check for drug interactions before adding medication"""
    new_drug = request.data.get('drug_name')
    current_meds = Medicine.objects.filter(user=request.user, is_active=True)

    # Use LLM or drug database to check interactions
    interactions = DrugInteractionService.check(new_drug, current_meds)

    return Response({
        'status': True,
        'has_interactions': len(interactions) > 0,
        'interactions': interactions
    })
```

**Deliverables:**
- [ ] Local notifications scheduled for medications
- [ ] Drug interaction checking on add medication
- [ ] Interaction warnings displayed in UI
- [ ] Notification settings in profile

---

## Technical Debt Items

### Code Quality
- [ ] Replace `print()` with `logging` module throughout
- [ ] Standardize API response format (`{status, result}` everywhere)
- [ ] Add pagination to all list endpoints
- [ ] Fix N+1 queries with `select_related()`
- [ ] Remove global variables in agent.py

### Database
- [ ] Add unique constraint on WatchVitals (user + timestamp)
- [ ] Add indexes on frequently queried fields
- [ ] Implement database query logging for optimization

### Security
- [ ] Migrate to JWT authentication
- [ ] Add rate limiting (django-ratelimit)
- [ ] Validate file uploads (type, size, malware)
- [ ] Review CORS settings
- [ ] Remove/secure `/watch-vitals/dev/` endpoint

---

## Feature Comparison: Current vs Target

| Feature | Current | Target |
|---------|---------|--------|
| Medication Tracking | Complete | Complete |
| Lab/Biomarker Analysis | Complete | Complete |
| Voice Agent | Works locally | Works in production |
| Apple Watch Vitals | Complete | Complete |
| Patient Reports | Models only | Full UI + PDF export |
| Caregiver Alerts | Not started | Full implementation |
| Drug Interactions | Stub only | LLM-powered checking |
| Side Effects | Agent can record | Full history + analysis |
| Notifications | Framework | Working reminders |
| Offline Mode | Not started | Sync-capable |
| FHIR Export | Stub | Working export |
| Unit Tests | None | 70%+ coverage |

---

## Success Metrics

### Sprint 1 (Week 1)
- [ ] 0 security vulnerabilities (token expiration, secret key)
- [ ] Kindura Reports screen functional
- [ ] All P0 items resolved

### Sprint 2 (Week 2)
- [ ] Caregiver management complete
- [ ] Medication recommendations usable
- [ ] Side effects viewable

### Sprint 3 (Week 3)
- [ ] Input validation on all user inputs
- [ ] 50%+ test coverage
- [ ] Insight dismissal works

### Sprint 4 (Week 4)
- [ ] Medication reminders working
- [ ] Drug interactions warned
- [ ] Ready for beta testing

---

## Quick Wins (Can Do Today)

1. **Add token expiration field** - 30 min
2. **Remove hardcoded secret key fallback** - 5 min
3. **Add logging instead of print** - 2 hours
4. **Add unique constraint on WatchVitals** - 15 min
5. **Add pagination to biomarkers endpoint** - 30 min

---

## Questions for Product Review

1. **Token expiration duration**: 24 hours? 7 days? Never expire?
2. **Caregiver notification triggers**: Missed medication? Abnormal vitals? All?
3. **Drug interaction data source**: Use LLM or drug database API?
4. **Offline mode priority**: Is this needed for MVP?
5. **Multi-language**: Which languages needed first?

---

## Next Steps

1. Review this plan with stakeholders
2. Prioritize Quick Wins for immediate improvement
3. Start Sprint 1 with security hardening
4. Set up test framework before adding features
5. Plan production deployment infrastructure
