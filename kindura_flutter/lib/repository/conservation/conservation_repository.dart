import 'package:kindura_ai/data/network/network_api_services.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';

class ConservationRepository {
  final _apiServices = NetworkApiServices();
  Future<dynamic> conservationApi() async {
    dynamic response = await _apiServices.getApi(AppUrl.conservationUrl);
    return response;
  }
}
