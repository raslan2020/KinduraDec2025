from rest_framework.response import Response
from rest_framework import status


def extract_error_message(serializer_errors):
    """
    Extract clean error message from serializer errors
    """
    if isinstance(serializer_errors, dict):
        # Handle field-specific errors
        for field, errors in serializer_errors.items():
            if field == 'non_field_errors':
                # Handle non-field errors (like authentication errors)
                if isinstance(errors, list) and len(errors) > 0:
                    return str(errors[0])
            else:
                # Handle field-specific errors
                if isinstance(errors, list) and len(errors) > 0:
                    return f"{field}: {str(errors[0])}"
                elif isinstance(errors, str):
                    return f"{field}: {errors}"
    elif isinstance(serializer_errors, str):
        return serializer_errors
    elif isinstance(serializer_errors, list) and len(serializer_errors) > 0:
        return str(serializer_errors[0])
    
    return "An error occurred"


def success_response(data=None, message="Success", status_code=status.HTTP_200_OK):
    """
    Standard success response format
    """
    response_data = {
        "status": True,
        "result": data if data is not None else {"message": message}
    }
    return Response(response_data, status=status_code)


def error_response(error_message="An error occurred", status_code=status.HTTP_400_BAD_REQUEST):
    """
    Standard error response format
    """
    # If error_message is a serializer errors dict, extract clean message
    if isinstance(error_message, dict):
        error_message = extract_error_message(error_message)
    
    response_data = {
        "status": False,
        "result": {"error": error_message}
    }
    return Response(response_data, status=status_code) 