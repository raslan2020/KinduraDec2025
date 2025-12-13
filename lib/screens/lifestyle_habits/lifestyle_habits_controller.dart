import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/utils/utils.dart';

class LifestyleHabitsController extends GetxController {
  // Observable Variables
  final smoking = false.obs;
  final drinkAlcohol = false.obs;
  final caffeineIntake = 0.obs;
  final requestStatus = Status.COMPLETED.obs;
  Map data = {
    "smoking": false,
    "drink_alcohol": false,
    "caffeine_intake": 0,
  };

  @override
  void onInit() {
    super.onInit();
  }

  void setSmoking(bool value) => smoking.value = value;
  void setDrinkAlcohol(bool value) => drinkAlcohol.value = value;
  void setCaffeineIntake(int value) => caffeineIntake.value = value;

  void setRequestStatus(Status value) => requestStatus.value = value;

  void saveLifestyleHabits() {
    // Validate caffeine intake
    if (caffeineIntake.value < 0) {
      Util.Snack_Bar("Warning", "Caffeine intake cannot be negative");
      return;
    }

    if (caffeineIntake.value > 20) {
      Util.Snack_Bar(
          "Warning", "Please enter a reasonable caffeine intake (0-20 cups)");
      return;
    }

    data["smoking"] = smoking.value;
    data["drink_alcohol"] = drinkAlcohol.value;
    data["caffeine_intake"] = caffeineIntake.value;

    print("the data is $data");

    Get.toNamed(RoutesName.physicalActivityScreen);
    // Simulate API call
  }
}
