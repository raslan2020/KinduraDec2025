import 'package:kindura_ai/data/network/network_api_services.dart';

import '../../res/app_url/app_url.dart';

class LoginRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> loginApi(var data) async {
    dynamic response = await _apiServices.postApi(data, AppUrl.loginUrl);
    return response;
  }
}

class SignupRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> signupApi(var data) async {
    dynamic response = await _apiServices.postApi(data, AppUrl.signupUrl);
    return response;
  }
}
