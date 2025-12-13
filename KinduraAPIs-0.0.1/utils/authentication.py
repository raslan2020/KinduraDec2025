import secrets
import logging
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth import get_user_model
from django.utils import timezone
from users.models import UserToken

User = get_user_model()
logger = logging.getLogger(__name__)


class SimpleTokenAuthentication(BaseAuthentication):
    """
    Token authentication with expiration checking for the medical app
    """

    def authenticate(self, request):
        token = request.META.get('HTTP_AUTHORIZATION')

        if not token:
            return None

        # Remove 'Token ' prefix if present
        if token.startswith('Token '):
            token = token[6:]
        # Also handle 'Bearer ' prefix
        elif token.startswith('Bearer '):
            token = token[7:]

        try:
            user_token = UserToken.objects.select_related('user').get(token=token)

            # Check if token is active
            if not user_token.is_active:
                logger.warning(f"Inactive token used for user {user_token.user.email}")
                raise AuthenticationFailed('Token is inactive')

            # Check if token is expired
            if user_token.expires_at and timezone.now() > user_token.expires_at:
                logger.warning(f"Expired token used for user {user_token.user.email}")
                raise AuthenticationFailed('Token has expired. Please login again.')

            # Update last used timestamp (don't save every time to reduce DB writes)
            # Only update if last_used_at is more than 1 hour ago
            if not user_token.last_used_at or (timezone.now() - user_token.last_used_at).seconds > 3600:
                user_token.last_used_at = timezone.now()
                user_token.save(update_fields=['last_used_at'])

            return (user_token.user, token)

        except UserToken.DoesNotExist:
            logger.warning(f"Invalid token attempted: {token[:10]}...")
            raise AuthenticationFailed('Invalid token')


def generate_token():
    """
    Generate a simple token for user authentication
    """
    return secrets.token_urlsafe(32)


def create_user_token(user):
    """
    Create a new token for a user
    """
    # Deactivate any existing tokens for this user
    UserToken.objects.filter(user=user, is_active=True).update(is_active=False)
    
    # Create new token
    token = generate_token()
    user_token = UserToken.objects.create(user=user, token=token)
    return user_token 