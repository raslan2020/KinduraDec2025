"""
Management command to clean up old vitals data based on user retention preferences.

Usage:
    python manage.py cleanup_vitals
    python manage.py cleanup_vitals --dry-run  # Preview what would be deleted

This command should be run daily via cron job or scheduled task:
    0 2 * * * cd /path/to/KinduraAPIs && ../.venv/bin/python manage.py cleanup_vitals

Retention Policy:
- Each user sets their own retention period: 30 or 60 days (max)
- Records older than user's retention period are deleted
- This saves database space while maintaining user control
"""

from django.core.management.base import BaseCommand
from django.utils import timezone
from django.db import transaction
from datetime import timedelta

from health_profile.models import WatchVitals
from users.models import User


class Command(BaseCommand):
    help = 'Clean up old vitals data based on user retention preferences (30 or 60 days max)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without actually deleting',
        )
        parser.add_argument(
            '--user-id',
            type=int,
            help='Clean up vitals for a specific user ID only',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        user_id = options.get('user_id')

        now = timezone.now()
        total_deleted = 0
        users_processed = 0

        # Get users to process
        if user_id:
            users = User.objects.filter(id=user_id)
        else:
            users = User.objects.all()

        self.stdout.write(self.style.NOTICE(
            f"{'[DRY RUN] ' if dry_run else ''}Starting vitals cleanup at {now.isoformat()}"
        ))

        for user in users:
            retention_days = user.vitals_retention_days or 60  # Default to 60 if not set
            cutoff_date = now - timedelta(days=retention_days)

            # Find old records for this user
            old_vitals = WatchVitals.objects.filter(
                user=user,
                recorded_at__lt=cutoff_date
            )

            count = old_vitals.count()

            if count > 0:
                if dry_run:
                    self.stdout.write(
                        f"  User {user.id} ({user.email}): Would delete {count} records "
                        f"older than {retention_days} days (cutoff: {cutoff_date.date()})"
                    )
                else:
                    with transaction.atomic():
                        deleted, _ = old_vitals.delete()
                        self.stdout.write(
                            f"  User {user.id} ({user.email}): Deleted {deleted} records "
                            f"older than {retention_days} days"
                        )
                        total_deleted += deleted

                users_processed += 1

        # Summary
        if dry_run:
            self.stdout.write(self.style.WARNING(
                f"\n[DRY RUN] Would process {users_processed} users. No records deleted."
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f"\nCompleted. Processed {users_processed} users, deleted {total_deleted} total records."
            ))
