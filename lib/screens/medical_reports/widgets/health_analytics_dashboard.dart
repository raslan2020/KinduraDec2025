import 'package:flutter/material.dart';
import 'package:kindura_ai/models/medical_reports/medical_report.dart';
import 'package:intl/intl.dart';

class HealthAnalyticsDashboard extends StatelessWidget {
  final List<VitalSigns> vitalSigns;
  final List<BloodTest> bloodTests;

  const HealthAnalyticsDashboard({
    super.key,
    required this.vitalSigns,
    required this.bloodTests,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Health Insights",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          SizedBox(height: 16),
          
          // Summary Cards
          Row(
            children: [
              Expanded(child: _buildSummaryCard(
                title: "Total Readings",
                value: (vitalSigns.length + bloodTests.length).toString(),
                icon: Icons.assessment,
                color: Colors.blue,
              )),
              SizedBox(width: 12),
              Expanded(child: _buildSummaryCard(
                title: "This Week",
                value: _getThisWeekCount().toString(),
                icon: Icons.calendar_today,
                color: Colors.green,
              )),
            ],
          ),
          
          SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildSummaryCard(
                title: "Abnormal",
                value: _getAbnormalCount().toString(),
                icon: Icons.warning,
                color: Colors.orange,
              )),
              SizedBox(width: 12),
              Expanded(child: _buildSummaryCard(
                title: "Critical",
                value: _getCriticalCount().toString(),
                icon: Icons.priority_high,
                color: Colors.red,
              )),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Vital Signs Overview
          _buildVitalSignsOverview(),
          
          SizedBox(height: 24),
          
          // Blood Tests Overview
          _buildBloodTestsOverview(),
          
          SizedBox(height: 24),
          
          // Health Trends
          _buildHealthTrends(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsOverview() {
    if (vitalSigns.isEmpty) {
      return _buildEmptySection("Vital Signs", Icons.favorite_outline);
    }

    final groupedSigns = <String, List<VitalSigns>>{};
    for (final sign in vitalSigns) {
      final type = sign.type ?? 'unknown';
      groupedSigns.putIfAbsent(type, () => []).add(sign);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              "Vital Signs Overview",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        ...groupedSigns.entries.map((entry) => _buildVitalTypeCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildVitalTypeCard(String type, List<VitalSigns> signs) {
    signs.sort((a, b) => (b.recordedAt ?? DateTime.now()).compareTo(a.recordedAt ?? DateTime.now()));
    final latest = signs.first;
    final previousWeek = signs.where((s) => 
        s.recordedAt != null && 
        DateTime.now().difference(s.recordedAt!).inDays <= 7).toList();
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: latest.statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForType(type),
              color: latest.statusColor,
              size: 16,
            ),
          ),
          
          SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(type),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  latest.displayValue,
                  style: TextStyle(
                    fontSize: 12,
                    color: latest.statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: latest.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  latest.status?.toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: latest.statusColor,
                  ),
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${previousWeek.length} this week',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTestsOverview() {
    if (bloodTests.isEmpty) {
      return _buildEmptySection("Blood Tests", Icons.biotech_outlined);
    }

    final recentTests = bloodTests.where((test) => 
        test.testDate != null && 
        DateTime.now().difference(test.testDate!).inDays <= 30).toList();

    final abnormalTests = bloodTests.where((test) => 
        test.status != null && 
        !['normal', 'good'].contains(test.status!.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.biotech, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text(
              "Blood Tests Overview",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      recentTests.length.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      'Recent Tests',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade300,
              ),
              
              Expanded(
                child: Column(
                  children: [
                    Text(
                      abnormalTests.length.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: abnormalTests.isEmpty ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      'Abnormal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTrends() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: Colors.purple, size: 20),
            SizedBox(width: 8),
            Text(
              "Health Trends",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              _buildTrendItem(
                "Blood Pressure",
                _getBloodPressureTrend(),
                Icons.favorite,
                Colors.red,
              ),
              Divider(),
              _buildTrendItem(
                "Heart Rate",
                _getHeartRateTrend(),
                Icons.monitor_heart,
                Colors.pink,
              ),
              Divider(),
              _buildTrendItem(
                "Weight",
                _getWeightTrend(),
                Icons.scale,
                Colors.green,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendItem(String title, String trend, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          trend,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySection(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey.shade400, size: 20),
            SizedBox(width: 8),
            Text(
              "$title Overview",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              "No $title data available",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _getThisWeekCount() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: 7));
    
    final vitalCount = vitalSigns.where((vs) => 
        vs.recordedAt != null && vs.recordedAt!.isAfter(weekStart)).length;
    final bloodCount = bloodTests.where((bt) => 
        bt.testDate != null && bt.testDate!.isAfter(weekStart)).length;
    
    return vitalCount + bloodCount;
  }

  int _getAbnormalCount() {
    final abnormalVitals = vitalSigns.where((vs) => 
        vs.status != null && 
        !['normal', 'good'].contains(vs.status!.toLowerCase())).length;
    final abnormalBlood = bloodTests.where((bt) => 
        bt.status != null && 
        !['normal', 'good'].contains(bt.status!.toLowerCase())).length;
    
    return abnormalVitals + abnormalBlood;
  }

  int _getCriticalCount() {
    final criticalVitals = vitalSigns.where((vs) => 
        vs.status != null && 
        ['critical', 'high', 'very high'].contains(vs.status!.toLowerCase())).length;
    final criticalBlood = bloodTests.where((bt) => 
        bt.status != null && 
        ['critical', 'high', 'very high'].contains(bt.status!.toLowerCase())).length;
    
    return criticalVitals + criticalBlood;
  }

  String _getBloodPressureTrend() {
    final bpSigns = vitalSigns
        .where((vs) => vs.type == 'blood_pressure')
        .toList();
    
    if (bpSigns.length < 2) return "Insufficient data";
    
    bpSigns.sort((a, b) => (a.recordedAt ?? DateTime.now())
        .compareTo(b.recordedAt ?? DateTime.now()));
    
    final recent = bpSigns.takeLast(3).toList();
    final normalCount = recent.where((s) => 
        s.status?.toLowerCase() == 'normal').length;
    
    if (normalCount == recent.length) return "Stable & Normal";
    if (normalCount > recent.length / 2) return "Improving";
    return "Needs Attention";
  }

  String _getHeartRateTrend() {
    final hrSigns = vitalSigns
        .where((vs) => vs.type == 'heart_rate')
        .toList();
    
    if (hrSigns.length < 2) return "Insufficient data";
    
    hrSigns.sort((a, b) => (a.recordedAt ?? DateTime.now())
        .compareTo(b.recordedAt ?? DateTime.now()));
    
    final recent = hrSigns.takeLast(3).toList();
    final normalCount = recent.where((s) => 
        s.status?.toLowerCase() == 'normal').length;
    
    if (normalCount == recent.length) return "Stable";
    if (normalCount > recent.length / 2) return "Improving";
    return "Variable";
  }

  String _getWeightTrend() {
    final weightSigns = vitalSigns
        .where((vs) => vs.type == 'weight')
        .toList();
    
    if (weightSigns.length < 2) return "Insufficient data";
    
    weightSigns.sort((a, b) => (a.recordedAt ?? DateTime.now())
        .compareTo(b.recordedAt ?? DateTime.now()));
    
    if (weightSigns.length >= 2) {
      final latest = weightSigns.last.numericValue ?? 0;
      final previous = weightSigns[weightSigns.length - 2].numericValue ?? 0;
      final diff = latest - previous;
      
      if (diff.abs() < 0.5) return "Stable";
      return diff > 0 ? "Increasing" : "Decreasing";
    }
    
    return "Stable";
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