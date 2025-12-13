import 'package:flutter/material.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Kindura AI"),
      body: Center(
        child: Text("Monitor"),
      ),
    );
  }
}
