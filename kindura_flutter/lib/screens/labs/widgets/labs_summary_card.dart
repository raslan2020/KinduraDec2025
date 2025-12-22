import 'package:flutter/material.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';
import 'package:intl/intl.dart';

class LabsSummaryCard extends StatelessWidget {
  final LabsSummary? summary;

  const LabsSummaryCard({super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return _buildEmptyState();
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200,
            blurRadius: 8,
            offset: Offset(0, 4),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.science,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Labs Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Updated ${DateFormat('MMM dd, HH:mm').format(summary!.lastUpdated)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  title: 'Total Biomarkers',
                  value: summary!.totalBiomarkers.toString(),
                  icon: Icons.biotech,
                ),
              ),
              
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
                margin: EdgeInsets.symmetric(horizontal: 16),
              ),
              
              Expanded(
                child: _buildStatItem(
                  title: 'Recent Tests',
                  value: summary!.recentTestsCount.toString(),
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  title: 'Abnormal',
                  value: summary!.abnormalCount.toString(),
                  icon: Icons.warning,
                  valueColor: summary!.abnormalCount > 0 ? Colors.orange.shade200 : null,
                ),
              ),
              
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
                margin: EdgeInsets.symmetric(horizontal: 16),
              ),
              
              Expanded(
                child: _buildStatItem(
                  title: 'Critical',
                  value: summary!.criticalCount.toString(),
                  icon: Icons.priority_high,
                  valueColor: summary!.criticalCount > 0 ? Colors.red.shade200 : null,
                ),
              ),
            ],
          ),
          
          // Featured biomarkers preview
          if (summary!.featuredBiomarkers.isNotEmpty) ...[
            SizedBox(height: 20),
            
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            
            SizedBox(height: 16),
            
            Text(
              'Key Biomarkers',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            SizedBox(height: 12),
            
            Row(
              children: summary!.featuredBiomarkers.take(3).map((biomarker) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          biomarker.definition.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        SizedBox(height: 4),
                        
                        if (biomarker.hasData)
                          Text(
                            biomarker.latestObservation!.displayValue,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else
                          Text(
                            'No data',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              Icons.science_outlined,
              size: 48,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),

            SizedBox(height: 12),

            Text(
              'No lab data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
              ),
            ),

            SizedBox(height: 4),

            Text(
              'Upload lab reports to get started',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(0.8),
              size: 16,
            ),
            
            SizedBox(width: 6),
            
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 4),
        
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}