import 'package:get/get.dart';
import 'package:kindura_ai/models/conservation/conservation_model.dart';

class ConservationDetailController extends GetxController {
  Result result = Result();
  var arguments = Get.arguments;
  @override
  void onInit() {
    super.onInit();
    result = arguments;
  }
}
