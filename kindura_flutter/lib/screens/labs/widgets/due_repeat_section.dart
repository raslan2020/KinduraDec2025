import 'package:flutter/material.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';
import 'package:intl/intl.dart';

class DueRepeatSection extends StatelessWidget {
  final List<BiomarkerWithTrend> dueForRepeat;
  final Function(BiomarkerWithTrend) onTapBiomarker;

  const DueRepeatSection({
    super.key,
    required this.dueForRepeat,
    required this.onTapBiomarker,
  });

  @override
  Widget build(BuildContext context) {
    if (dueForRepeat.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.purple.shade700,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tests Due for Repeat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                      Text(
                        '${dueForRepeat.length} test${dueForRepeat.length > 1 ? 's' : ''} may need retesting',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dueForRepeat.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of due tests
          ...dueForRepeat.take(5).map((biomarker) => _buildDueItem(biomarker)),

          // Show more link if more than 5
          if (dueForRepeat.length > 5)
            Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Use "Due for Repeat" filter to see all ${dueForRepeat.length} tests',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDueItem(BiomarkerWithTrend biomarker) {
    final lastTest = biomarker.latestObservation;
    final daysSinceTest = lastTest != null
        ? DateTime.now().difference(lastTest.collectedAt).inDays
        : null;

    String timeSinceText;
    Color urgencyColor;

    if (daysSinceTest == null) {
      timeSinceText = 'Never tested';
      urgencyColor = Colors.red.shade600;
    } else if (daysSinceTest > 365) {
      final months = (daysSinceTest / 30).round();
      timeSinceText = '$months months ago';
      urgencyColor = Colors.red.shade600;
    } else if (daysSinceTest > 180) {
      final months = (daysSinceTest / 30).round();
      timeSinceText = '$months months ago';
      urgencyColor = Colors.orange.shade600;
    } else {
      final months = (daysSinceTest / 30).round();
      timeSinceText = '$months months ago';
      urgencyColor = Colors.purple.shade600;
    }

    // Get recommendation based on biomarker type
    final recommendation = _getRepeatRecommendation(biomarker, daysSinceTest);

    return InkWell(
      onTap: () => onTapBiomarker(biomarker),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.purple.shade100),
          ),
        ),
        child: Row(
          children: [
            // Urgency indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),

            // Biomarker info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    biomarker.definition.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: urgencyColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        timeSinceText,
                        style: TextStyle(
                          fontSize: 11,
                          color: urgencyColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (lastTest != null) ...[
                        Text(
                          ' (${DateFormat('MMM dd, yyyy').format(lastTest.collectedAt)})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (recommendation.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      recommendation,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Last value if available
            if (lastTest != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    lastTest.displayValue,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(lastTest.status),
                    ),
                  ),
                  Text(
                    _getStatusText(lastTest.status),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getStatusColor(lastTest.status),
                    ),
                  ),
                ],
              ),

            SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _getRepeatRecommendation(BiomarkerWithTrend biomarker, int? daysSinceTest) {
    final category = biomarker.definition.category.toLowerCase();
    final name = biomarker.definition.name.toLowerCase();
    final status = biomarker.latestObservation?.status;

    // If result was abnormal, recommend sooner follow-up
    if (status == ResultStatus.criticalLow || status == ResultStatus.criticalHigh) {
      return 'Critical result - follow up with your doctor promptly';
    }

    if (status == ResultStatus.high || status == ResultStatus.low) {
      return 'Previous result was abnormal - consider retesting to monitor';
    }

    // Standard recommendations by category
    if (category.contains('lipid') || name.contains('cholesterol') || name.contains('triglyceride')) {
      return 'Lipid panel typically repeated every 4-6 months if abnormal, yearly if normal';
    }

    if (category.contains('diabetes') || name.contains('glucose') || name.contains('hba1c') || name.contains('a1c')) {
      return 'Blood sugar tests recommended every 3 months for diabetics, yearly for screening';
    }

    if (category.contains('thyroid') || name.contains('tsh') || name.contains('t3') || name.contains('t4')) {
      return 'Thyroid function tests typically repeated every 6-12 months';
    }

    if (category.contains('kidney') || name.contains('creatinine') || name.contains('bun') || name.contains('gfr')) {
      return 'Kidney function tests recommended annually or as directed';
    }

    if (category.contains('liver') || name.contains('alt') || name.contains('ast') || name.contains('bilirubin')) {
      return 'Liver function tests recommended annually or if symptoms present';
    }

    if (name.contains('vitamin d')) {
      return 'Vitamin D typically retested 3 months after supplementation changes';
    }

    if (name.contains('b12')) {
      return 'Vitamin B12 recommended yearly or every 6 months if deficient';
    }

    if (daysSinceTest != null && daysSinceTest > 365) {
      return 'This test is over a year old - consider discussing with your doctor';
    }

    return 'Standard retest interval varies - consult your healthcare provider';
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
        return 'Critical Low';
      case ResultStatus.criticalHigh:
        return 'Critical High';
      case ResultStatus.high:
        return 'High';
      case ResultStatus.low:
        return 'Low';
      case ResultStatus.normal:
        return 'Normal';
      case ResultStatus.unknown:
        return 'Unknown';
    }
  }
}
