import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kindura_ai/models/medical_reports/medical_report.dart';
import 'package:intl/intl.dart';

class VitalTrendChart extends StatelessWidget {
  final List<VitalSigns> vitalSigns;
  final String type;
  final Color primaryColor;

  const VitalTrendChart({
    super.key,
    required this.vitalSigns,
    required this.type,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (vitalSigns.isEmpty) {
      return _buildEmptyState();
    }

    final filteredSigns = vitalSigns.where((vs) => vs.type == type).toList();
    if (filteredSigns.isEmpty) {
      return _buildEmptyState();
    }

    // Sort by date
    filteredSigns.sort((a, b) => (a.recordedAt ?? DateTime.now())
        .compareTo(b.recordedAt ?? DateTime.now()));

    return Container(
      height: 300,
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
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForType(type),
                  color: primaryColor,
                  size: 20,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Last ${filteredSigns.length} readings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStats(filteredSigns),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Chart
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getInterval(filteredSigns),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 0.8,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < filteredSigns.length) {
                          final date = filteredSigns[value.toInt()].recordedAt;
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              date != null ? DateFormat('MM/dd').format(date) : '',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                        return Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                lineBarsData: _buildLineBarData(filteredSigns),
                minX: 0,
                maxX: (filteredSigns.length - 1).toDouble(),
                minY: _getMinY(filteredSigns),
                maxY: _getMaxY(filteredSigns),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final vitalSign = filteredSigns[spot.x.toInt()];
                        return LineTooltipItem(
                          '${vitalSign.displayValue}\n${vitalSign.recordedAt != null ? DateFormat('MMM dd, HH:mm').format(vitalSign.recordedAt!) : ''}',
                          TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconForType(type),
              size: 48,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12),
            Text(
              'No ${_getDisplayName(type).toLowerCase()} data',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Add readings to see trends',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(List<VitalSigns> signs) {
    if (signs.isEmpty) return SizedBox.shrink();

    final values = signs.map((s) => s.numericValue).where((v) => v != null).cast<double>().toList();
    if (values.isEmpty) return SizedBox.shrink();

    final latest = values.last;
    final average = values.reduce((a, b) => a + b) / values.length;
    final trend = values.length > 1 ? (latest - values[values.length - 2]) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getTrendColor(trend).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                trend > 0 ? Icons.trending_up : trend < 0 ? Icons.trending_down : Icons.trending_flat,
                size: 14,
                color: _getTrendColor(trend),
              ),
              SizedBox(width: 4),
              Text(
                trend > 0 ? '+${trend.toStringAsFixed(1)}' : trend.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getTrendColor(trend),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Avg: ${average.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _buildLineBarData(List<VitalSigns> signs) {
    if (type == 'blood_pressure') {
      return _buildBloodPressureData(signs);
    } else {
      return _buildSingleValueData(signs);
    }
  }

  List<LineChartBarData> _buildBloodPressureData(List<VitalSigns> signs) {
    final systolicSpots = <FlSpot>[];
    final diastolicSpots = <FlSpot>[];

    for (int i = 0; i < signs.length; i++) {
      final parts = signs[i].value?.split('/') ?? [];
      if (parts.length == 2) {
        final systolic = double.tryParse(parts[0]);
        final diastolic = double.tryParse(parts[1]);
        if (systolic != null && diastolic != null) {
          systolicSpots.add(FlSpot(i.toDouble(), systolic));
          diastolicSpots.add(FlSpot(i.toDouble(), diastolic));
        }
      }
    }

    return [
      LineChartBarData(
        spots: systolicSpots,
        isCurved: true,
        color: Colors.red,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: Colors.red,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      ),
      LineChartBarData(
        spots: diastolicSpots,
        isCurved: true,
        color: Colors.red.shade300,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: Colors.red.shade300,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      ),
    ];
  }

  List<LineChartBarData> _buildSingleValueData(List<VitalSigns> signs) {
    final spots = <FlSpot>[];

    for (int i = 0; i < signs.length; i++) {
      final value = signs[i].numericValue;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }

    return [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: primaryColor,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: primaryColor,
              strokeWidth: 1,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: primaryColor.withOpacity(0.1),
        ),
      ),
    ];
  }

  double _getMinY(List<VitalSigns> signs) {
    if (type == 'blood_pressure') {
      return 40.0; // Minimum diastolic
    }
    
    final values = signs.map((s) => s.numericValue).where((v) => v != null).cast<double>().toList();
    if (values.isEmpty) return 0;
    
    final min = values.reduce((a, b) => a < b ? a : b);
    return (min * 0.9).floorToDouble();
  }

  double _getMaxY(List<VitalSigns> signs) {
    if (type == 'blood_pressure') {
      return 200.0; // Maximum systolic
    }
    
    final values = signs.map((s) => s.numericValue).where((v) => v != null).cast<double>().toList();
    if (values.isEmpty) return 100;
    
    final max = values.reduce((a, b) => a > b ? a : b);
    return (max * 1.1).ceilToDouble();
  }

  double _getInterval(List<VitalSigns> signs) {
    final range = _getMaxY(signs) - _getMinY(signs);
    return (range / 5).ceilToDouble();
  }

  Color _getTrendColor(double trend) {
    if (trend.abs() < 1) return Colors.grey;
    return trend > 0 ? Colors.orange : Colors.green;
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