import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/conservation/conservation_model.dart';
import 'package:kindura_ai/repository/conservation/conservation_repository.dart';
import 'package:kindura_ai/utils/utils.dart';

class ConservationController extends GetxController {
  final _conservationRepository = ConservationRepository();
  final conservationRepository = ConservationModel().obs;
  final requestStatus = Status.COMPLETED.obs;
  final errors = ''.obs;

  @override
  void onInit() {
    super.onInit();
    getConservation();
  }

  Future<void> getConservation() async {
    requestStatus.value = Status.LOADING;
    try {
      var value = await _conservationRepository.conservationApi();

      if (value['status'] == true) {
        conservationRepository.value = ConservationModel.fromJson(value);
      } else {
        Util.Snack_Bar("Warning", "Something went wrong in getConservation");
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error connecting in getConservation: $error');
    } finally {
      requestStatus.value = Status.COMPLETED;
    }
  }
}
