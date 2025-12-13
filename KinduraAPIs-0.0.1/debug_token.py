#!/usr/bin/env python
import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
django.setup()

from users.models import UserToken

def test_token():
    token = "TaYll_82__ED4xZbgGnWzkmqRV5dpRq8Bdu7gi2Tv1Y"

    print(f"🔍 Testing token: {token[:20]}...")

    try:
        # Check if token exists
        user_token = UserToken.objects.get(token=token)
        print(f"✅ Token found!")
        print(f"   User: {user_token.user.username}")
        print(f"   Active: {user_token.is_active}")
        print(f"   Created: {user_token.created_at}")

        # Check if active
        if user_token.is_active:
            print("✅ Token is active and should work")
        else:
            print("❌ Token is inactive - this is the problem")

    except UserToken.DoesNotExist:
        print("❌ Token does not exist in database")

    # List all tokens
    print(f"\n📋 All tokens in database:")
    for token_obj in UserToken.objects.all():
        print(f"   {token_obj.token[:20]}... | User: {token_obj.user.username} | Active: {token_obj.is_active}")

if __name__ == "__main__":
    test_token()