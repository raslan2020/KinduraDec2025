import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class HealthProfileRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> healthProfileApi(var data) async {
    dynamic response = await _apiServices.putApi(data, AppUrl.healthProfileUrl);
    return response;
  }
}
