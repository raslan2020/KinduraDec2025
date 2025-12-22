import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';
import 'package:intl/intl.dart';

class BiomarkerCard extends StatelessWidget {
  final BiomarkerWithTrend biomarker;
  final VoidCallback? onTap;
  final VoidCallback? onAddValue;

  const BiomarkerCard({
    super.key,
    required this.biomarker,
    this.onTap,
    this.onAddValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey.shade800;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final shadowColor = isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade200;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getBorderColor(isDark),
                width: biomarker.latestObservation?.status == ResultStatus.normal ? 1 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            biomarker.definition.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (biomarker.definition.loincCode != null) ...[
                            SizedBox(height: 2),
                            Text(
                              'LOINC: ${biomarker.definition.loincCode}',
                              style: TextStyle(
                                fontSize: 10,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Status chip
                    if (biomarker.hasData) ...[
                      _buildStatusChip(),
                    ] else ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No Data',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],

                    // Add value button
                    IconButton(
                      onPressed: onAddValue,
                      icon: Icon(Icons.add_circle_outline, size: 20, color: isDark ? Colors.white70 : null),
                      constraints: BoxConstraints(),
                      padding: EdgeInsets.all(4),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                if (biomarker.hasData) ...[
                  // Current value and trend
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildValueSection(),
                      ),
                      
                      // Sparkline chart
                      if (biomarker.recentObservations.length > 1)
                        Expanded(
                          flex: 3,
                          child: _buildSparkline(),
                        ),
                    ],
                  ),
                  
                  SizedBox(height: 8),

                  // Reference range
                  _buildReferenceRange(context),
                ] else ...[
                  // No data state
                  Container(
                    height: 60,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timeline,
                            size: 24,
                            color: subtextColor,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No measurements yet',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Last updated
                if (biomarker.latestObservation != null) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: subtextColor),
                      SizedBox(width: 4),
                      Text(
                        'Last: ${DateFormat('MMM dd, yyyy').format(biomarker.latestObservation!.collectedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),

                      Spacer(),

                      // Total measurements count
                      Text(
                        '${biomarker.totalObservations} measurement${biomarker.totalObservations != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final observation = biomarker.latestObservation!;
    final color = _getStatusColor(observation.status);
    final text = _getStatusText(observation.status);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildValueSection() {
    final observation = biomarker.latestObservation!;
    final color = _getStatusColor(observation.status);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          observation.displayValue,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        
        SizedBox(height: 4),
        
        // Trend indicator
        if (biomarker.trendDirection != TrendDirection.insufficientData)
          Row(
            children: [
              Icon(
                _getTrendIcon(biomarker.trendDirection),
                size: 14,
                color: _getTrendColor(biomarker.trendDirection),
              ),
              SizedBox(width: 4),
              Text(
                _getTrendText(biomarker.trendDirection),
                style: TextStyle(
                  fontSize: 11,
                  color: _getTrendColor(biomarker.trendDirection),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSparkline() {
    final observations = biomarker.recentObservations
        .where((obs) => obs.valueNum != null)
        .toList();

    if (observations.length < 2) {
      return SizedBox.shrink();
    }

    // Sort by date
    observations.sort((a, b) => a.collectedAt.compareTo(b.collectedAt));

    // Create spots for the line chart
    final spots = observations.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.valueNum!);
    }).toList();

    final minY = observations.map((o) => o.valueNum!).reduce((a, b) => a < b ? a : b);
    final maxY = observations.map((o) => o.valueNum!).reduce((a, b) => a > b ? a : b);

    // Handle case where all values are the same
    final range = maxY - minY;
    final padding = range > 0 ? range * 0.2 : maxY * 0.1; // Use 10% of value if no range
    final interval = range > 0 ? range / 3 : 1.0; // Default to 1.0 if no range

    // Calculate reference range zone if available
    final latestObs = biomarker.latestObservation!;

    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(vertical: 4),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) {
              // Draw subtle reference range zone
              if (latestObs.refLow != null && latestObs.refHigh != null) {
                if (value >= latestObs.refLow! && value <= latestObs.refHigh!) {
                  return FlLine(
                    color: Colors.green.withOpacity(0.05),
                    strokeWidth: 1,
                  );
                }
              }
              return FlLine(
                color: Colors.grey.withOpacity(0.1),
                strokeWidth: 0.5,
              );
            },
          ),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (observations.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _getStatusColor(biomarker.latestObservation!.status),
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final obs = observations[index];
                  final dotColor = _getStatusColor(obs.status);

                  return FlDotCirclePainter(
                    radius: 3.5,
                    color: dotColor,
                    strokeWidth: 0,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getStatusColor(biomarker.latestObservation!.status).withOpacity(0.15),
                    _getStatusColor(biomarker.latestObservation!.status).withOpacity(0.02),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
    );
  }

  Widget _buildReferenceRange(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final observation = biomarker.latestObservation!;

    if (observation.refLow == null && observation.refHigh == null && observation.refRange == null) {
      return SizedBox.shrink();
    }

    String rangeText;
    if (observation.refRange != null) {
      rangeText = 'Normal: ${observation.refRange}';
    } else if (observation.refLow != null && observation.refHigh != null) {
      rangeText = 'Normal: ${observation.refLow} - ${observation.refHigh} ${observation.unitOriginal ?? ''}';
    } else if (observation.refLow != null) {
      rangeText = 'Normal: ≥${observation.refLow} ${observation.unitOriginal ?? ''}';
    } else if (observation.refHigh != null) {
      rangeText = 'Normal: ≤${observation.refHigh} ${observation.unitOriginal ?? ''}';
    } else {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        rangeText,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Color _getBorderColor(bool isDark) {
    if (!biomarker.hasData) return isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    final status = biomarker.latestObservation!.status;
    switch (status) {
      case ResultStatus.criticalLow:
      case ResultStatus.criticalHigh:
        return Colors.red.shade700;
      case ResultStatus.high:
      case ResultStatus.low:
        return Colors.orange.shade400;
      case ResultStatus.normal:
        return Colors.green.shade400;
      case ResultStatus.unknown:
        return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    }
  }

  Color _getStatusColor(ResultStatus status) {
    switch (status) {
      case ResultStatus.criticalLow:
      case ResultStatus.criticalHigh:
        return Colors.red.shade700;
      case ResultStatus.high:
      case ResultStatus.low:
        return Colors.orange.shade600;
      case ResultStatus.normal:
        return Colors.green.shade600;
      case ResultStatus.unknown:
        return Colors.grey.shade500;
    }
  }

  String _getStatusText(ResultStatus status) {
    switch (status) {
      case ResultStatus.criticalLow:
        return 'CRITICAL LOW';
      case ResultStatus.criticalHigh:
        return 'CRITICAL HIGH';
      case ResultStatus.high:
        return 'HIGH';
      case ResultStatus.low:
        return 'LOW';
      case ResultStatus.normal:
        return 'NORMAL';
      case ResultStatus.unknown:
        return 'UNKNOWN';
    }
  }

  IconData _getTrendIcon(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.improving:
        return Icons.trending_up;
      case TrendDirection.declining:
        return Icons.trending_down;
      case TrendDirection.stable:
        return Icons.trending_flat;
      case TrendDirection.insufficientData:
        return Icons.help_outline;
    }
  }

  Color _getTrendColor(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.improving:
        return Colors.green.shade600;
      case TrendDirection.declining:
        return Colors.red.shade600;
      case TrendDirection.stable:
        return Colors.blue.shade600;
      case TrendDirection.insufficientData:
        return Colors.grey.shade500;
    }
  }

  String _getTrendText(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.improving:
        return 'Improving';
      case TrendDirection.declining:
        return 'Declining';
      case TrendDirection.stable:
        return 'Stable';
      case TrendDirection.insufficientData:
        return 'Insufficient data';
    }
  }
}