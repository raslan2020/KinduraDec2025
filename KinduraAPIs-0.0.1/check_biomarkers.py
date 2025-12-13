#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
django.setup()

from medical_reports.models import Biomarker
from users.models import User

user = User.objects.get(email='ralabaji@gmail.com')
biomarkers = Biomarker.objects.filter(user=user)

print(f"\n=== Biomarker Database Status ===")
print(f"Total biomarkers: {biomarkers.count()}")
print(f"Unique biomarker names: {len(set(biomarkers.values_list('name', flat=True)))}")

if biomarkers.count() > 0:
    print(f"\n=== Sample Biomarkers ===")
    for b in biomarkers[:10]:
        print(f"  - {b.name}: {b.value} {b.unit} on {b.test_date} (Report ID: {b.report_id})")
else:
    print("\n⚠️  NO BIOMARKERS FOUND IN DATABASE!")
    print("This means the data was deleted when reports were deleted.")
