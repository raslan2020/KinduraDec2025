import 'package:flutter/material.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';

class HealthInsightsSection extends StatelessWidget {
  final List<HealthInsight> insights;
  final Function(String) onDismiss;

  const HealthInsightsSection({
    super.key,
    required this.insights,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return SizedBox.shrink();
    }

    // Group insights by severity
    final criticalInsights = insights.where((i) => i.severity == InsightSeverity.critical).toList();
    final urgentInsights = insights.where((i) => i.severity == InsightSeverity.urgent).toList();
    final warningInsights = insights.where((i) => i.severity == InsightSeverity.warning).toList();
    final infoInsights = insights.where((i) => i.severity == InsightSeverity.info).toList();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                'Health Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              
              Spacer(),
              
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${insights.length} active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Critical insights first
          ...criticalInsights.map((insight) => _buildInsightCard(insight, context)),
          ...urgentInsights.map((insight) => _buildInsightCard(insight, context)),
          ...warningInsights.map((insight) => _buildInsightCard(insight, context)),
          ...infoInsights.map((insight) => _buildInsightCard(insight, context)),
          
          // Show disclaimer
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These insights are for informational purposes only and are not a substitute for professional medical advice, diagnosis, or treatment.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(HealthInsight insight, BuildContext context) {
    final color = _getSeverityColor(insight.severity);
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getSeverityIcon(insight.severity),
                    size: 16,
                    color: color,
                  ),
                ),
                
                SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getSeverityText(insight.severity),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                          Spacer(),
                          
                          IconButton(
                            onPressed: () => onDismiss(insight.id),
                            icon: Icon(Icons.close, size: 18),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 4),
                      
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Action recommendation
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.recommend, size: 16, color: Colors.green.shade600),
                          SizedBox(width: 6),
                          Text(
                            'Recommendation',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 6),
                      
                      Text(
                        insight.actionRecommendation,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Related biomarkers
                if (insight.relatedBiomarkers.isNotEmpty) ...[
                  SizedBox(height: 8),
                  
                  Text(
                    'Related biomarkers:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  
                  SizedBox(height: 4),
                  
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: insight.relatedBiomarkers.map((biomarker) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          biomarker,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return Colors.red.shade700;
      case InsightSeverity.urgent:
        return Colors.red.shade400;
      case InsightSeverity.warning:
        return Colors.orange.shade600;
      case InsightSeverity.info:
        return Colors.blue.shade600;
    }
  }

  IconData _getSeverityIcon(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return Icons.error;
      case InsightSeverity.urgent:
        return Icons.warning;
      case InsightSeverity.warning:
        return Icons.info;
      case InsightSeverity.info:
        return Icons.lightbulb;
    }
  }

  String _getSeverityText(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return 'CRITICAL';
      case InsightSeverity.urgent:
        return 'URGENT';
      case InsightSeverity.warning:
        return 'WARNING';
      case InsightSeverity.info:
        return 'INFO';
    }
  }
}