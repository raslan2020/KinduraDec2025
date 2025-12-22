import 'package:get/get.dart';
import 'package:kindura_ai/models/courses_list/courses_list_model.dart';

class CourseDetailController extends GetxController {
  var arguments = Get.arguments;
  Result? course;

  @override
  void onInit() {
    super.onInit();
    course = arguments["course"];
  }
}
