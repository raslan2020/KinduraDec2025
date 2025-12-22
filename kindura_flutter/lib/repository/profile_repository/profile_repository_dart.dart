import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class ProfileRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> profileApi(var data) async {
    dynamic response = await _apiServices.putApi(data, AppUrl.profileUrl);
    return response;
  }
}
