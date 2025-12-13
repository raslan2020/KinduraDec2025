import 'package:flutter/material.dart';

class SleepSummaryCard extends StatelessWidget {
  final String date;
  final String deepSleep;
  final String totalSleep;
  final String quality;
  final Color qualityColor;

  const SleepSummaryCard({
    super.key,
    required this.date,
    required this.deepSleep,
    required this.totalSleep,
    required this.quality,
    required this.qualityColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.nightlight_round, color: Colors.deepPurple),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Deep sleep: $deepSleep',
                    style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(totalSleep,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(quality,
                    style: TextStyle(fontSize: 12, color: qualityColor)),
              )
            ],
          ),
        ],
      ),
    );
  }
}
