import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kindura_ai/res/assets/image_constant.dart';
import 'package:intl/intl.dart';

class MedsVitaminCard extends StatelessWidget {
  final String medicine;
  final String deepSleep;
  final String totalSleep;
  final String svgIcon;
  final String time;
  final Color qualityColor;
  final bool taken;
  final int scheduleId;
  final VoidCallback? onStatusToggle;
  final String? lastUpdated;

  const MedsVitaminCard({
    super.key,
    required this.medicine,
    required this.deepSleep,
    required this.totalSleep,
    required this.svgIcon,
    required this.qualityColor,
    required this.time,
    required this.taken,
    required this.scheduleId,
    this.onStatusToggle,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    String formatToAmPm(String time24h) {
      final time = DateFormat("HH:mm:ss").parse(time24h);
      return DateFormat("h:mm a").format(time); // e.g. 9:45 PM
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: taken ? Colors.green.shade50 : const Color(0xFFF5F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: taken ? Colors.green.shade300 : Colors.grey.shade300,
          width: taken ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              ImageConstant.medVitaminIcon,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(medicine,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            decoration: taken ? TextDecoration.lineThrough : null,
                            color: taken ? Colors.grey.shade600 : Colors.black,
                          )),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: taken ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        taken ? 'TAKEN' : 'PENDING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: taken ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(deepSleep, style: TextStyle(color: Colors.grey.shade700)),
                if (lastUpdated != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      lastUpdated!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(totalSleep,
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Row(
                children: [
                  SvgPicture.asset(
                    ImageConstant.timerIcon,
                    height: 12,
                    width: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    formatToAmPm(time),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(width: 5.w),
          Column(
            children: [
              GestureDetector(
                onTap: onStatusToggle,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: taken ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: taken ? Colors.green.shade300 : Colors.orange.shade300,
                    ),
                  ),
                  child: Icon(
                    taken ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: taken ? Colors.green.shade600 : Colors.orange.shade600,
                    size: 24,
                  ),
                ),
              ),
              if (onStatusToggle != null)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'TAP',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }
}
