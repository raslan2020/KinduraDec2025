import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';
import 'package:kindura_ai/screens/labs/labs_controller.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:intl/intl.dart';

class BiomarkerDetailScreen extends StatefulWidget {
  const BiomarkerDetailScreen({super.key});

  @override
  State<BiomarkerDetailScreen> createState() => _BiomarkerDetailScreenState();
}

class _BiomarkerDetailScreenState extends State<BiomarkerDetailScreen> with TickerProviderStateMixin {
  final controller = Get.find<LabsController>();
  late TabController _tabController;
  BiomarkerWithTrend? biomarker;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    biomarker = Get.arguments as BiomarkerWithTrend?;

    if (biomarker != null) {
      controller.loadBiomarkerDetail(biomarker!.definition.id);
      // Load AI insights when screen opens
      controller.loadBiomarkerAiInsights(biomarker!.definition.id);
    }
  }

  @override
  void dispose() {
    // Clear AI insights when leaving the screen
    controller.clearBiomarkerAiInsights();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final appBarColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final tabBarColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (biomarker == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('Biomarker Detail', style: TextStyle(color: textColor)),
          backgroundColor: appBarColor,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(child: Text('Biomarker not found', style: TextStyle(color: textColor))),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(biomarker!.definition.name, style: TextStyle(color: textColor)),
        backgroundColor: appBarColor,
        elevation: isDark ? 0 : 1,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            onPressed: () => _showAddValueDialog(),
            icon: Icon(Icons.add, color: textColor),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportBiomarkerData();
                  break;
                case 'share':
                  _shareBiomarker();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'export', child: Text('Export Data')),
              PopupMenuItem(value: 'share', child: Text('Share')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddValueDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Current value header
          _buildCurrentValueHeader(),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: tabBarColor,
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: isDark ? Colors.white : Colors.blue,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: 'Timeline'),
                Tab(text: 'Insights'),
                Tab(text: 'About'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineTab(context),
                _buildInsightsTab(context),
                _buildAboutTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentValueHeader() {
    return Obx(() {
      final selectedBiomarker = controller.selectedBiomarker.value ?? biomarker!;
      final hasData = selectedBiomarker.hasData;
      
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasData 
                ? [
                    _getStatusColor(selectedBiomarker.latestObservation!.status),
                    _getStatusColor(selectedBiomarker.latestObservation!.status).withOpacity(0.8),
                  ]
                : [Colors.grey.shade400, Colors.grey.shade500],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasData) ...[
                        Text(
                          selectedBiomarker.latestObservation!.displayValue,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        SizedBox(height: 4),
                        
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(selectedBiomarker.latestObservation!.status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'No Data',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        SizedBox(height: 4),
                        
                        Text(
                          'Add your first measurement',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Trend indicator
                if (hasData && selectedBiomarker.trendDirection != TrendDirection.insufficientData)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getTrendIcon(selectedBiomarker.trendDirection),
                          color: Colors.white,
                          size: 24,
                        ),
                        
                        SizedBox(height: 4),
                        
                        Text(
                          _getTrendText(selectedBiomarker.trendDirection),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            if (hasData) ...[
              SizedBox(height: 12),
              
              Text(
                'Last measured: ${DateFormat('MMM dd, yyyy').format(selectedBiomarker.latestObservation!.collectedAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              
              if (selectedBiomarker.latestObservation!.laboratoryName != null) ...[
                SizedBox(height: 4),
                Text(
                  'Lab: ${selectedBiomarker.latestObservation!.laboratoryName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  Widget _buildTimelineTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;

    return Obx(() {
      final selectedBiomarker = controller.selectedBiomarker.value ?? biomarker!;

      if (!selectedBiomarker.hasData) {
        return _buildEmptyState(context);
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Chart
            Container(
              height: 300,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: _buildTimelineChart(context, selectedBiomarker),
            ),

            SizedBox(height: 20),

            // Observations list
            _buildObservationsList(context, selectedBiomarker),
          ],
        ),
      );
    });
  }

  Widget _buildInsightsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference range explanation
          _buildReferenceRangeCard(context),

          SizedBox(height: 16),

          // Clinical significance
          _buildClinicalSignificanceCard(context),

          SizedBox(height: 16),

          // Related insights
          _buildRelatedInsightsCard(context),
        ],
      ),
    );
  }

  Widget _buildAboutTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic information
          _buildInfoCard(context),

          SizedBox(height: 16),

          // Learn More section (AI-generated)
          _buildLearnMoreCard(context),

          SizedBox(height: 16),

          // LOINC information
          if (biomarker!.definition.loincCode != null)
            _buildLoincCard(context),
        ],
      ),
    );
  }

  Widget _buildLearnMoreCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Obx(() {
      final aiInsights = controller.biomarkerAiInsights.value;
      final isLoading = controller.aiInsightsStatus.value == Status.LOADING;

      if (isLoading) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, size: 20, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    'Learn More',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Spacer(),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildLoadingPlaceholder(context),
            ],
          ),
        );
      }

      if (aiInsights == null) {
        return SizedBox.shrink();
      }

      final learnMore = aiInsights.learnMore;

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, size: 20, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Learn More',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // What it measures
            _buildLearnMoreSection(
              icon: Icons.science,
              title: 'What It Measures',
              content: learnMore.whatItMeasures,
              color: Colors.blue,
            ),
            SizedBox(height: 12),

            // Why it matters
            _buildLearnMoreSection(
              icon: Icons.health_and_safety,
              title: 'Why It Matters',
              content: learnMore.whyItMatters,
              color: Colors.green,
            ),

            // Factors affecting
            if (learnMore.factorsAffecting.isNotEmpty) ...[
              SizedBox(height: 12),
              _buildLearnMoreListSection(
                icon: Icons.tune,
                title: 'Factors That Can Affect Levels',
                items: learnMore.factorsAffecting,
                color: Colors.purple,
              ),
            ],

            // Lifestyle tips
            if (learnMore.lifestyleTips.isNotEmpty) ...[
              SizedBox(height: 12),
              _buildLearnMoreListSection(
                icon: Icons.tips_and_updates,
                title: 'Lifestyle Tips',
                items: learnMore.lifestyleTips,
                color: Colors.teal,
              ),
            ],

            // When to seek help
            if (learnMore.whenToSeekHelp != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, size: 20, color: Colors.red.shade600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'When to Seek Medical Help',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            learnMore.whenToSeekHelp!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildLearnMoreSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearnMoreListSection({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) => Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
        ),
      ],
    );
  }

  Widget _buildTimelineChart(BuildContext context, BiomarkerWithTrend selectedBiomarker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark ? Colors.grey[700]! : Colors.grey.shade200;
    final textColor = isDark ? Colors.grey[400]! : Colors.grey.shade600;

    final observations = selectedBiomarker.recentObservations
        .where((obs) => obs.valueNum != null)
        .toList();

    if (observations.length < 2) {
      return Center(
        child: Text(
          'Need at least 2 measurements to show trend',
          style: TextStyle(color: textColor),
        ),
      );
    }

    observations.sort((a, b) => a.collectedAt.compareTo(b.collectedAt));

    final spots = observations.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.valueNum!);
    }).toList();

    final minY = observations.map((o) => o.valueNum!).reduce((a, b) => a < b ? a : b);
    final maxY = observations.map((o) => o.valueNum!).reduce((a, b) => a > b ? a : b);

    // Get reference ranges
    final latestObs = selectedBiomarker.latestObservation!;
    final refLow = latestObs.refLow;
    final refHigh = latestObs.refHigh;

    // Calculate chart bounds to include reference range
    double chartMinY = minY;
    double chartMaxY = maxY;

    if (refLow != null) {
      chartMinY = chartMinY < refLow ? chartMinY : refLow * 0.8;
    }
    if (refHigh != null) {
      chartMaxY = chartMaxY > refHigh ? chartMaxY : refHigh * 1.2;
    }

    // Handle case where all values are the same
    final range = chartMaxY - chartMinY;
    final padding = range > 0 ? range * 0.15 : chartMaxY * 0.1;
    final interval = range > 0 ? range / 5 : 1.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: gridColor,
              strokeWidth: 1,
            );
          },
        ),
        // Reference range background zone
        extraLinesData: ExtraLinesData(
          horizontalLines: refLow != null && refHigh != null
              ? [
                  // Top of normal range
                  HorizontalLine(
                    y: refHigh,
                    color: Colors.green.shade400.withOpacity(0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  // Bottom of normal range
                  HorizontalLine(
                    y: refLow,
                    color: Colors.green.shade400.withOpacity(0.3),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ]
              : [],
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: interval, // Use the safe interval we calculated above
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: observations.length > 6 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < observations.length) {
                  final date = observations[index].collectedAt;
                  final isLatest = index == observations.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('MM/dd/yy').format(date),
                      style: TextStyle(
                        fontSize: 10,
                        color: isLatest ? Colors.blue.shade700 : textColor,
                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
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
          show: false,
        ),
        lineBarsData: [
          // Reference range shaded area
          if (refLow != null && refHigh != null)
            LineChartBarData(
              spots: [
                FlSpot(0, refLow),
                FlSpot((observations.length - 1).toDouble(), refLow),
              ],
              isCurved: false,
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.shade50,
                cutOffY: refHigh,
                applyCutOffY: true,
              ),
            ),
          // Main data line
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: Colors.orange.shade600,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final obs = observations[index];
                final dotColor = _getStatusColor(obs.status);
                final isLatest = index == observations.length - 1;

                return FlDotCirclePainter(
                  radius: isLatest ? 5.5 : 4.5,
                  color: dotColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        ],
        minX: 0,
        maxX: (observations.length - 1).toDouble(),
        minY: chartMinY - padding,
        maxY: chartMaxY + padding,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                if (spot.barIndex == (refLow != null && refHigh != null ? 1 : 0)) {
                  final observation = observations[spot.x.toInt()];
                  return LineTooltipItem(
                    '${observation.displayValue}\n${DateFormat('MMM dd, yyyy').format(observation.collectedAt)}',
                    TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildObservationsList(BuildContext context, BiomarkerWithTrend selectedBiomarker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;

    final observations = selectedBiomarker.recentObservations;
    observations.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Measurements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showModifyDataDialog(context),
              icon: Icon(Icons.edit, size: 16),
              label: Text('Modify'),
            ),
          ],
        ),

        SizedBox(height: 12),

        ...observations.map((observation) => GestureDetector(
          onTap: () => _showEditObservationDialog(context, observation),
          child: Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        observation.displayValue,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(observation.status),
                        ),
                      ),

                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm').format(observation.collectedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),

                      if (observation.notes != null) ...[
                        SizedBox(height: 4),
                        Text(
                          observation.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStatusColor(observation.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(observation.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(observation.status),
                    ),
                  ),
                ),

                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: subtitleColor, size: 20),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final subtitleColor = isDark ? Colors.grey[500] : Colors.grey.shade500;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline, size: 80, color: textColor),
          SizedBox(height: 16),
          Text(
            'No measurements yet',
            style: TextStyle(fontSize: 18, color: textColor),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first measurement to see trends',
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showModifyDataDialog(context),
            icon: Icon(Icons.add),
            label: Text('Add Measurement'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceRangeCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.grey.shade800;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;

    final latestObs = biomarker!.latestObservation;
    final hasRefRange = latestObs != null &&
        (latestObs.refLow != null || latestObs.refHigh != null);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System references for a ${_getAgeGenderDescription()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
              ),
              InkWell(
                onTap: _showConfigureReferenceDialog,
                child: Text(
                  'Configure',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Normal range indicator
          if (hasRefRange) ...[
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Normal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Text(
                  '${latestObs.refLow?.toStringAsFixed(2) ?? '0.00'} — ${latestObs.refHigh?.toStringAsFixed(2) ?? '0.00'} ${latestObs.unitOriginal ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This biomarker has optimal ranges',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // TODO: Show learn more dialog
                      Get.snackbar(
                        'Learn More',
                        'Reference ranges are evidence-based thresholds that help identify optimal, borderline, and concerning values for health markers.',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: Duration(seconds: 4),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          'Try it',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Learn more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No reference range available. Tap Configure to set custom ranges.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getAgeGenderDescription() {
    // TODO: Get actual age and gender from user profile
    return 'male, 50 years old';
  }

  void _showConfigureReferenceDialog() {
    Get.snackbar(
      'Configure Reference Range',
      'Reference range configuration coming soon. You\'ll be able to customize ranges based on your demographics and health goals.',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
    );
  }

  Widget _buildClinicalSignificanceCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade700;

    return Obx(() {
      final aiInsights = controller.biomarkerAiInsights.value;
      final isLoading = controller.aiInsightsStatus.value == Status.LOADING;

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_information, size: 20, color: Colors.blue.shade600),
                SizedBox(width: 8),
                Text(
                  'Clinical Significance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Spacer(),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (isLoading)
              _buildLoadingPlaceholder(context)
            else if (aiInsights != null) ...[
              // AI-generated summary
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSeverityColor(aiInsights.clinicalSignificance.severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getSeverityColor(aiInsights.clinicalSignificance.severity).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  aiInsights.clinicalSignificance.summary,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Detailed interpretation
              Text(
                aiInsights.clinicalSignificance.interpretation,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              // Trend analysis
              if (aiInsights.clinicalSignificance.trendAnalysis != null) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.blue.shade600),
                    SizedBox(width: 6),
                    Text(
                      'Trend Analysis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  aiInsights.clinicalSignificance.trendAnalysis!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ] else
              Text(
                biomarker!.definition.clinicalSignificance ??
                    'This biomarker provides insights into your health status.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
          ],
        ),
      );
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red.shade600;
      case 'moderate':
        return Colors.orange.shade600;
      case 'mild':
        return Colors.yellow.shade700;
      case 'normal':
        return Colors.green.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBg = isDark ? Colors.grey[700]! : Colors.grey.shade200;
    final shimmerBgLight = isDark ? Colors.grey[600]! : Colors.grey.shade100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: shimmerBg,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        SizedBox(height: 8),
        Container(
          height: 40,
          width: double.infinity,
          decoration: BoxDecoration(
            color: shimmerBgLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedInsightsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Obx(() {
      final aiInsights = controller.biomarkerAiInsights.value;
      final isLoading = controller.aiInsightsStatus.value == Status.LOADING;

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber.shade600),
                SizedBox(width: 8),
                Text(
                  'Related Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (isLoading)
              _buildLoadingPlaceholder(context)
            else if (aiInsights != null && aiInsights.relatedInsights.isNotEmpty) ...[
              ...aiInsights.relatedInsights.map((insight) => Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getInsightTypeColor(insight.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getInsightTypeColor(insight.type).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _getInsightTypeIcon(insight.type),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                            _buildPriorityBadge(insight.priority),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          insight.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )),
              // Recommendations section
              if (aiInsights.recommendations.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8),
                ...aiInsights.recommendations.map((rec) => Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _getUrgencyIcon(rec.urgency),
                            size: 18,
                            color: _getUrgencyColor(rec.urgency),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rec.action,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  rec.reason,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ] else
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey.shade500),
                    SizedBox(width: 8),
                    Text(
                      'No related insights available.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Color _getInsightTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return Colors.purple;
      case 'correlation':
        return Colors.blue;
      case 'lifestyle':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _getInsightTypeIcon(String type) {
    IconData iconData;
    Color color;
    switch (type.toLowerCase()) {
      case 'medication':
        iconData = Icons.medication;
        color = Colors.purple;
        break;
      case 'correlation':
        iconData = Icons.compare_arrows;
        color = Colors.blue;
        break;
      case 'lifestyle':
        iconData = Icons.favorite;
        color = Colors.green;
        break;
      case 'warning':
        iconData = Icons.warning_amber;
        color = Colors.orange;
        break;
      default:
        iconData = Icons.info_outline;
        color = Colors.grey;
    }
    return Icon(iconData, size: 16, color: color);
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'immediate':
        return Icons.priority_high;
      case 'soon':
        return Icons.schedule;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'immediate':
        return Colors.red;
      case 'soon':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildInfoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade700;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About ${biomarker!.definition.name}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 12),

          _buildInfoRow(context, 'Category', biomarker!.categoryDisplayName),
          _buildInfoRow(context, 'Preferred Unit', biomarker!.definition.preferredUnit ?? 'N/A'),

          if (biomarker!.definition.description != null) ...[
            SizedBox(height: 8),
            Text(
              biomarker!.definition.description!,
              style: TextStyle(color: subtitleColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoincCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOINC Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          SizedBox(height: 8),
          _buildInfoRow(context, 'LOINC Code', biomarker!.definition.loincCode!),
          SizedBox(height: 4),
          Text(
            'LOINC (Logical Observation Identifiers Names and Codes) is a universal standard for identifying medical laboratory observations.',
            style: TextStyle(
              fontSize: 12,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final valueColor = isDark ? Colors.white : Colors.grey.shade800;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddValueDialog() {
    _showModifyDataDialog(Get.context!);
  }

  // ======== MODIFY DATA DIALOGS ========

  void _showModifyDataDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;

    final selectedBiomarker = controller.selectedBiomarker.value ?? biomarker!;
    final observations = selectedBiomarker.recentObservations.toList();
    observations.sort((a, b) => b.collectedAt.compareTo(a.collectedAt));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subtitleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Modify ${biomarker!.definition.name}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: subtitleColor),
                  ),
                ],
              ),
            ),

            // Add new value button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddNewValueDialog(context);
                },
                icon: Icon(Icons.add),
                label: Text('Add New Value'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ),

            SizedBox(height: 16),

            // Divider with label
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: borderColor)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Previous Values',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: borderColor)),
                ],
              ),
            ),

            SizedBox(height: 8),

            // Values list
            Expanded(
              child: observations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined, size: 48, color: subtitleColor),
                          SizedBox(height: 12),
                          Text(
                            'No measurements yet',
                            style: TextStyle(color: subtitleColor, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: observations.length,
                      itemBuilder: (context, index) {
                        final obs = observations[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: ListTile(
                            onTap: () {
                              Get.back(); // Close bottom sheet
                              Future.delayed(Duration(milliseconds: 100), () {
                                _showEditObservationDialog(Get.context!, obs);
                              });
                            },
                            leading: Container(
                              width: 8,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getStatusColor(obs.status),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            title: Text(
                              obs.displayValue,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(obs.status),
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('MMM dd, yyyy • HH:mm').format(obs.collectedAt),
                              style: TextStyle(color: subtitleColor, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    Get.back(); // Close bottom sheet
                                    Future.delayed(Duration(milliseconds: 100), () {
                                      _showEditObservationDialog(Get.context!, obs);
                                    });
                                  },
                                  icon: Icon(Icons.edit, size: 20, color: Colors.blue),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Get.back(); // Close bottom sheet first
                                    Future.delayed(Duration(milliseconds: 100), () {
                                      _confirmDeleteObservation(Get.context!, obs);
                                    });
                                  },
                                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewValueDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;

    final valueController = TextEditingController();
    final notesController = TextEditingController();
    final selectedDate = DateTime.now().obs;
    final latestObs = biomarker?.latestObservation;
    final unit = latestObs?.unitOriginal ?? biomarker?.definition.preferredUnit ?? 'mg/dL';

    Get.dialog(
      AlertDialog(
        backgroundColor: cardBg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Value for',
              style: TextStyle(fontSize: 14, color: subtitleColor),
            ),
            Text(
              biomarker!.definition.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last value info
              if (latestObs != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Value',
                            style: TextStyle(fontSize: 11, color: subtitleColor),
                          ),
                          Text(
                            latestObs.displayValue,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'on ${DateFormat('MMM dd, yyyy').format(latestObs.collectedAt)}',
                            style: TextStyle(fontSize: 11, color: subtitleColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // New value input
              Text(
                'New Value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: valueController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter value',
                        hintStyle: TextStyle(color: subtitleColor),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(unit, style: TextStyle(color: textColor)),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Collection date
              Text(
                'Collection Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Obx(() => InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        selectedDate.value = date;
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: subtitleColor),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate.value),
                            style: TextStyle(color: textColor),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_drop_down, color: subtitleColor),
                        ],
                      ),
                    ),
                  )),

              SizedBox(height: 16),

              // Notes
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Add context or notes...',
                  hintStyle: TextStyle(color: subtitleColor),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(valueController.text);
              if (value == null) {
                Get.snackbar('Error', 'Please enter a valid number');
                return;
              }
              // Call controller to add the observation
              controller.addBiomarkerObservation(
                biomarkerId: biomarker!.definition.id,
                value: value,
                unit: unit,
                collectedAt: selectedDate.value,
                notes: notesController.text.isEmpty ? null : notesController.text,
              );
              Get.back();
            },
            child: Text('Add Value'),
          ),
        ],
      ),
    );
  }

  void _showEditObservationDialog(BuildContext context, Observation observation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey.shade600;
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;

    final valueController = TextEditingController(text: observation.valueNum?.toString() ?? '');
    final notesController = TextEditingController(text: observation.notes ?? '');
    final selectedDate = observation.collectedAt.obs;
    final unit = observation.unitOriginal ?? biomarker?.definition.preferredUnit ?? 'mg/dL';

    Get.dialog(
      AlertDialog(
        backgroundColor: cardBg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Value for',
              style: TextStyle(fontSize: 14, color: subtitleColor),
            ),
            Text(
              biomarker!.definition.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Value input
              Text(
                'Value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: valueController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter value',
                        hintStyle: TextStyle(color: subtitleColor),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(unit, style: TextStyle(color: textColor)),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Collection date
              Text(
                'Collection Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Obx(() => InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.value,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        selectedDate.value = date;
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: subtitleColor),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate.value),
                            style: TextStyle(color: textColor),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_drop_down, color: subtitleColor),
                        ],
                      ),
                    ),
                  )),

              SizedBox(height: 16),

              // Notes
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Add context or notes...',
                  hintStyle: TextStyle(color: subtitleColor),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _confirmDeleteObservation(context, observation),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(valueController.text);
              if (value == null) {
                Get.snackbar('Error', 'Please enter a valid number');
                return;
              }
              // Call controller to update the observation
              controller.updateBiomarkerObservation(
                observationId: observation.id,
                value: value,
                collectedAt: selectedDate.value,
                notes: notesController.text.isEmpty ? null : notesController.text,
              );
              Get.back();
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteObservation(BuildContext context, Observation observation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    Get.dialog(
      AlertDialog(
        backgroundColor: cardBg,
        title: Text('Delete Measurement?', style: TextStyle(color: textColor)),
        content: Text(
          'Are you sure you want to delete this measurement?\n\n${observation.displayValue} on ${DateFormat('MMM dd, yyyy').format(observation.collectedAt)}\n\nThis action cannot be undone.',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteBiomarkerObservation(observation.id);
              Get.back();
              // If we were in the modify dialog, close it too
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportBiomarkerData() {
    // TODO: Implement export
    Get.snackbar(
      'Export',
      'Export functionality coming soon',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _shareBiomarker() {
    // TODO: Implement share
    Get.snackbar(
      'Share',
      'Share functionality coming soon',
      snackPosition: SnackPosition.BOTTOM,
    );
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

  String _getTrendText(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.improving:
        return 'Improving';
      case TrendDirection.declining:
        return 'Declining';
      case TrendDirection.stable:
        return 'Stable';
      case TrendDirection.insufficientData:
        return 'Insufficient';
    }
  }
}