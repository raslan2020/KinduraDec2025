import 'package:flutter/material.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/screens/course_detail/course_detail_controller.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final CourseDetailController controller = Get.put(CourseDetailController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Course Details",
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoTile("Name", controller.course!.course!.name!),
              _infoTile("Start Date", controller.course!.course!.startDate!),
              _infoTile(
                  "Duration", "${controller.course!.course!.duration} days"),
              _infoTile("Patient History",
                  controller.course!.course!.patientHistory!),
              _infoTile("Current Situation",
                  controller.course!.course!.currentSituation!),
              _infoTile("Doctor Instructions",
                  controller.course!.course!.doctorInstructions!),
              const SizedBox(height: 20),
              _sectionTitle("Medicines"),
              ...controller.course!.medicines!.map<Widget>((medicine) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(medicine.name!),
                      subtitle: Text(medicine.description!),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              _sectionTitle("Schedules"),
              ...controller.course!.schedules!.map<Widget>((schedule) {
                return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(schedule.medicineName!),
                        subtitle: Text(
                          "Time: ${schedule.time} — Dosage: ${schedule.dosage}",
                        ),
                      ),
                    ));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }
}
