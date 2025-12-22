import 'package:flutter/material.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';

class ReportCheckupScreen extends StatefulWidget {
  const ReportCheckupScreen({super.key});

  @override
  State<ReportCheckupScreen> createState() => _ReportCheckupScreenState();
}

class _ReportCheckupScreenState extends State<ReportCheckupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Kindura AI"),
      body: Center(
        child: Text("Report Checkup"),
      ),
    );
  }
}
