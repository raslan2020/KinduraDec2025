import 'package:get/get.dart';

class HealthController extends GetxController {
  var bloodPressure = '120/80'.obs;
  var heartRate = 72.obs;
  var temperature = 98.6.obs;
  var oxygen = 98.obs;
  var recordedTime = '8:00 AM'.obs;

  var selectedTab = 'Vital Signs'.obs;

  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  void recordNewMeasurement() {
    // Simulated data update
    bloodPressure.value = '118/79';
    heartRate.value = 75;
    temperature.value = 98.7;
    oxygen.value = 97;
    recordedTime.value = '9:00 AM';
  }
}
