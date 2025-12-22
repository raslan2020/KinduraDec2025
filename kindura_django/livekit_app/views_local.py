"""
Local development views for testing without LiveKit cloud
"""
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from utils.response_utils import success_response, error_response


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def get_token_mock(request):
    """
    Mock LiveKit token generator for local testing
    Returns a dummy token that won't connect to LiveKit but allows testing other features
    """
    try:
        data = request.data
        
        # Log the request for debugging
        print(f"Mock LiveKit token requested for: {data.get('identity')}")
        
        # Return a mock response that indicates local testing mode
        return success_response({
            'token': 'mock_token_for_local_testing',
            'message': 'Local testing mode - LiveKit voice features disabled',
            'local_mode': True
        })
        
    except Exception as e:
        return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_room_mock(request):
    """
    Mock room deletion for local testing
    """
    try:
        room_name = request.data.get('room', 'unknown')
        print(f"Mock room deletion requested for: {room_name}")
        
        return success_response(
            f'Mock: Room "{room_name}" deleted (local testing mode)'
        )
        
    except Exception as e:
        return error_response(str(e), status.HTTP_500_INTERNAL_SERVER_ERROR)