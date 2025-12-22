#!/usr/bin/env python
"""
Clean up duplicate biomarker entries caused by:
1. Unit conversions (same biomarker in different units)
2. Multiple uploads of same report
3. Future dates from parsing errors
"""

import os
import django
from datetime import datetime

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
django.setup()

from medical_reports.models import Biomarker
from users.models import User
from collections import defaultdict

def clean_duplicates():
    user = User.objects.get(email='ralabaji@gmail.com')

    # Get all biomarkers
    biomarkers = list(Biomarker.objects.filter(user=user).order_by('name', 'test_date'))

    # Group by (name, test_date, value)
    grouped = defaultdict(list)
    for b in biomarkers:
        # Normalize the key
        key = (b.name.lower().strip(), str(b.test_date), f"{b.value:.2f}" if b.value else "0")
        grouped[key].append(b)

    duplicates_removed = 0
    future_dates_fixed = 0

    # For each group, keep only the first one (preferring mg/dL or standard units)
    for key, biomarker_list in grouped.items():
        if len(biomarker_list) > 1:
            # Sort by preferred units (mg/dL, mmol/L, etc.)
            preferred_units = ['mg/dL', 'mg/dl', 'mmol/L', 'g/dL', 'g/L']
            biomarker_list.sort(key=lambda b: (
                0 if b.unit in preferred_units else 1,  # Prefer standard units
                b.id  # Then by ID (keep earlier entries)
            ))

            # Keep the first one, delete the rest
            to_keep = biomarker_list[0]
            to_delete = biomarker_list[1:]

            print(f"\n{to_keep.name}:")
            print(f"  Keeping: {to_keep.value} {to_keep.unit}, Date: {to_keep.test_date}, ID: {to_keep.id}")
            for b in to_delete:
                print(f"  Deleting: {b.value} {b.unit}, Date: {b.test_date}, ID: {b.id}")
                b.delete()
                duplicates_removed += 1

    # Fix future dates
    today = datetime.now().date()
    future_biomarkers = Biomarker.objects.filter(user=user, test_date__gt=today)

    for b in future_biomarkers:
        old_date = b.test_date
        # Subtract 1 year
        b.test_date = b.test_date.replace(year=b.test_date.year - 1)
        b.save()
        print(f"Fixed future date: {b.name} {old_date} -> {b.test_date}")
        future_dates_fixed += 1

    print(f"\n\n=== Summary ===")
    print(f"Duplicates removed: {duplicates_removed}")
    print(f"Future dates fixed: {future_dates_fixed}")
    print(f"Total biomarkers remaining: {Biomarker.objects.filter(user=user).count()}")

if __name__ == '__main__':
    clean_duplicates()
