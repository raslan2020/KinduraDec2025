import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/home/course_list.dart';
import 'package:kindura_ai/repository/home_repository/home_repository.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'dart:async';

class MedsVitaminController extends GetxController {
  final HomeRepository _homeRepository = HomeRepository();
  final requestStatus = Status.COMPLETED.obs;
  final courseList = CourseList().obs;
  RxString errors = ''.obs;
  
  // Auto-refresh timer
  Timer? _refreshTimer;
  final RxBool autoRefreshEnabled = true.obs;
  final RxInt refreshIntervalMinutes = 5.obs;
  
  // Medication status tracking
  final RxMap<int, bool> medicationStatus = <int, bool>{}.obs;
  final RxMap<int, DateTime> lastUpdated = <int, DateTime>{}.obs;
  
  // Manual logging
  final RxBool isLogging = false.obs;

  @override
  void onInit() {
    super.onInit();
    getCourseList();
    _startAutoRefresh();
  }
  
  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }
  
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (autoRefreshEnabled.value) {
      _refreshTimer = Timer.periodic(
        Duration(minutes: refreshIntervalMinutes.value),
        (timer) => getCourseList(),
      );
    }
  }
  
  void toggleAutoRefresh() {
    autoRefreshEnabled.value = !autoRefreshEnabled.value;
    if (autoRefreshEnabled.value) {
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }
  
  void setRefreshInterval(int minutes) {
    refreshIntervalMinutes.value = minutes;
    if (autoRefreshEnabled.value) {
      _startAutoRefresh();
    }
  }

  Future<void> getCourseList() async {
    requestStatus.value = Status.LOADING;
    try {
      var value = await _homeRepository.courseList();

      if (value['status'] == true) {
        courseList.value = CourseList.fromJson(value);
        _updateMedicationStatusTracking();
        print('📊 [MEDICATION_UPDATE] Course list refreshed at ${DateTime.now()}');
      } else {
        Util.Snack_Bar("Warning", "Something went wrong in getCourseList");
      }
    } catch (error) {
      errors.value = error.toString();
      print('❌ [MEDICATION_ERROR] Error connecting in getCourseList: $error');
    } finally {
      requestStatus.value = Status.COMPLETED;
    }
  }
  
  void _updateMedicationStatusTracking() {
    if (courseList.value.result?.schedules != null) {
      for (var schedule in courseList.value.result!.schedules!) {
        if (schedule.id != null) {
          medicationStatus[schedule.id!] = schedule.taken ?? false;
          lastUpdated[schedule.id!] = DateTime.now();
        }
      }
    }
  }
  
  // Manual medication logging
  Future<void> toggleMedicationStatus(int scheduleId) async {
    if (isLogging.value) return;
    
    isLogging.value = true;
    try {
      // Find the schedule
      var schedule = courseList.value.result?.schedules?.firstWhere(
        (s) => s.id == scheduleId,
      );
      
      if (schedule != null) {
        // Update local state immediately for better UX
        bool newStatus = !(schedule.taken ?? false);
        medicationStatus[scheduleId] = newStatus;
        lastUpdated[scheduleId] = DateTime.now();
        
        // Update the schedule object
        schedule.taken = newStatus;
        courseList.refresh();
        
        print('💊 [MEDICATION_LOG] ${schedule.medicineName} marked as ${newStatus ? "taken" : "not taken"} at ${DateTime.now()}');
        
        // Here you would normally call an API to update the backend
        // await _homeRepository.updateMedicationStatus(scheduleId, newStatus);
        
        String message = newStatus 
          ? "✅ ${schedule.medicineName} marked as taken"
          : "❌ ${schedule.medicineName} marked as not taken";
        
        Util.Snack_Bar("Medication Updated", message);
      }
    } catch (error) {
      print('❌ [MEDICATION_ERROR] Error updating medication status: $error');
      Util.Snack_Bar("Error", "Failed to update medication status");
    } finally {
      isLogging.value = false;
    }
  }
  
  String getLastUpdatedText(int scheduleId) {
    if (lastUpdated.containsKey(scheduleId)) {
      var time = lastUpdated[scheduleId]!;
      var now = DateTime.now();
      var diff = now.difference(time);
      
      if (diff.inMinutes < 1) {
        return "Updated just now";
      } else if (diff.inMinutes < 60) {
        return "Updated ${diff.inMinutes}m ago";
      } else {
        return "Updated ${diff.inHours}h ago";
      }
    }
    return "No recent updates";
  }
}
