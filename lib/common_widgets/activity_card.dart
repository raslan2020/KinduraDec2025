import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kindura_ai/res/assets/image_constant.dart';

class ActivityCard extends StatelessWidget {
  final String date;
  final int steps;
  final int falls;
  final int tremors;

  const ActivityCard({
    required this.date,
    required this.steps,
    required this.falls,
    required this.tremors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFEBFCF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFD5FDE1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  colorFilter: ColorFilter.mode(
                    Colors.green,
                    BlendMode.srcIn,
                  ),
                  ImageConstant.bloodPressueIcon,
                ),
              ),
              SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    date,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text("Daily Activity",
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              activityMetric("Steps", steps.toString(), Colors.green[800]!),
              activityMetric("Falls", falls.toString(),
                  falls == 0 ? Colors.green : Colors.red),
              activityMetric(
                  "Tremor Episodes", tremors.toString(), Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget activityMetric(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
