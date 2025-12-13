import 'package:flutter/material.dart';
import 'package:kindura_ai/models/medical_reports/medical_report.dart';
import 'package:intl/intl.dart';

class VitalSignsCard extends StatelessWidget {
  final VitalSigns vitalSigns;

  const VitalSignsCard({super.key, required this.vitalSigns});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: vitalSigns.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForType(vitalSigns.type ?? ''),
              color: vitalSigns.statusColor,
              size: 24,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getDisplayName(vitalSigns.type ?? ''),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: vitalSigns.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        vitalSigns.status?.toUpperCase() ?? 'UNKNOWN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: vitalSigns.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 4),
                
                Text(
                  vitalSigns.displayValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: vitalSigns.statusColor,
                  ),
                ),
                
                if (vitalSigns.notes != null && vitalSigns.notes!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    vitalSigns.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Date/Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                vitalSigns.recordedAt != null
                    ? DateFormat('MMM dd').format(vitalSigns.recordedAt!)
                    : 'No date',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                vitalSigns.recordedAt != null
                    ? DateFormat('HH:mm').format(vitalSigns.recordedAt!)
                    : '',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'blood_pressure':
        return Icons.favorite;
      case 'heart_rate':
        return Icons.monitor_heart;
      case 'temperature':
        return Icons.thermostat;
      case 'weight':
        return Icons.scale;
      case 'blood_sugar':
        return Icons.bloodtype;
      default:
        return Icons.health_and_safety;
    }
  }

  String _getDisplayName(String type) {
    switch (type) {
      case 'blood_pressure':
        return 'Blood Pressure';
      case 'heart_rate':
        return 'Heart Rate';
      case 'temperature':
        return 'Temperature';
      case 'weight':
        return 'Weight';
      case 'blood_sugar':
        return 'Blood Sugar';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}