import 'package:get/get.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';

class AppException implements Exception {
  final _message;
  final _prefix;
  final UserPreferences userPreferences = UserPreferences();
  AppException([this._message, this._prefix]);

  String toString() {
    return '$_prefix$_message';
  }
}

class InternetException extends AppException {
  InternetException([String? message]) : super(message, 'No Internet');
}

class RequestTimeOut extends AppException {
  RequestTimeOut([String? message]) : super(message, 'Request TIme out');
}

class ServerException extends AppException {
  ServerException([String? message]) : super(message, 'Server Error');
}

class InvalidURL extends AppException {
  InvalidURL([String? message]) : super(message, 'Invalid URL');
}

class FetchDataException extends AppException {
  FetchDataException([String? message])
      : super(message, 'Error While Communication');
  // NOTE: Removed auto-logout behavior - exceptions should not have side effects
  // Logout should only happen explicitly when user requests it or on 401 with proper handling
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String? message])
      : super(message, 'Unauthorized');
}
