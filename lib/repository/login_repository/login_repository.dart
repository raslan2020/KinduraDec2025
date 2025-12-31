import 'package:kindura_ai/data/network/network_api_services.dart';

import '../../res/app_url/app_url.dart';

class LoginRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> loginApi(var data) async {
    // Login doesn't require auth - we're trying to GET a token
    dynamic response = await _apiServices.postApi(data, AppUrl.loginUrl, requireAuth: false);
    return response;
  }
}

class SignupRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> signupApi(var data) async {
    // Signup doesn't require auth - we're creating a new user
    dynamic response = await _apiServices.postApi(data, AppUrl.signupUrl, requireAuth: false);
    return response;
  }
}
