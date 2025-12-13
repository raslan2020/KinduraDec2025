#!/usr/bin/env python
import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'medical_app.settings')
django.setup()

from users.models import UserToken
from django.contrib.auth import get_user_model

User = get_user_model()

def detailed_token_debug():
    print("📋 All users in system:")
    for user in User.objects.all():
        print(f"   User: {user.username} | ID: {user.id} | Email: {user.email}")

    print("\n📋 All tokens in database:")
    for token_obj in UserToken.objects.all():
        print(f"   Token: {token_obj.token[:20]}... | User: {token_obj.user.username} | Active: {token_obj.is_active} | Created: {token_obj.created_at}")

    # Check specific token
    test_token = "TaYll_82__ED4xZbgGnWzkmqRV5dpRq8Bdu7gi2Tv1Y"
    try:
        user_token = UserToken.objects.get(token=test_token)
        print(f"\n✅ Test Token Details:")
        print(f"   User ID: {user_token.user.id}")
        print(f"   Username: {user_token.user.username}")
        print(f"   Is Active: {user_token.is_active}")
        print(f"   Created: {user_token.created_at}")
        print(f"   Full Token: {user_token.token}")

        # Test authentication manually
        from utils.authentication import SimpleTokenAuthentication
        from django.test import RequestFactory

        print(f"\n🔍 Testing authentication manually...")

        # Test with Token prefix
        factory = RequestFactory()
        request = factory.get('/api/medications/', HTTP_AUTHORIZATION=f'Token {test_token}')

        auth = SimpleTokenAuthentication()
        try:
            result = auth.authenticate(request)
            if result:
                user, token = result
                print(f"✅ Authentication successful with Token prefix: User {user.username}")
            else:
                print("❌ Authentication returned None")
        except Exception as e:
            print(f"❌ Authentication failed with Token prefix: {e}")

        # Test with raw token
        request2 = factory.get('/api/medications/', HTTP_AUTHORIZATION=test_token)
        try:
            result2 = auth.authenticate(request2)
            if result2:
                user, token = result2
                print(f"✅ Authentication successful with raw token: User {user.username}")
            else:
                print("❌ Authentication returned None")
        except Exception as e:
            print(f"❌ Authentication failed with raw token: {e}")

    except UserToken.DoesNotExist:
        print("❌ Test token not found")

if __name__ == "__main__":
    detailed_token_debug()