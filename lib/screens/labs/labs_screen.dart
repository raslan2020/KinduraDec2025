import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/common_widgets/home_app_bar.dart';
import 'package:kindura_ai/screens/labs/labs_controller.dart';
import 'package:kindura_ai/screens/labs/widgets/labs_summary_card.dart';
import 'package:kindura_ai/screens/labs/widgets/biomarker_card.dart';
import 'package:kindura_ai/screens/labs/widgets/health_insights_section.dart';
import 'package:kindura_ai/screens/labs/widgets/category_tabs.dart';
import 'package:kindura_ai/screens/labs/widgets/due_repeat_section.dart';
import 'package:kindura_ai/screens/bottom_navigation/bottom_navigation_controller.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:kindura_ai/repository/biomarkers_repository/biomarkers_repository.dart';
import 'package:kindura_ai/models/biomarkers/biomarker_models.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> with TickerProviderStateMixin {
  final controller = Get.put(LabsController());
  late TabController _categoryTabController;

  @override
  void initState() {
    super.initState();
    _categoryTabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  Widget _shimmerCard({double height = 120, bool? isDarkMode}) {
    final isDark = isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12.w),
        ),
        height: height.h,
        width: double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () {
            // Labs is a tab in bottom navigation, so switch to home tab (index 0)
            final navController = Get.find<BottomNavController>();
            navController.currentIndex.value = 0;
          },
        ),
        title: Text(
          'Labs & Biomarkers',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        backgroundColor: appBarBg,
        elevation: isDark ? 0 : 1,
        centerTitle: true,
        iconTheme: IconThemeData(color: iconColor),
        actions: [
          IconButton(
            onPressed: _showSearchDialog,
            icon: Icon(Icons.search, color: iconColor),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  controller.exportFHIR();
                  break;
                case 'refresh':
                  controller.loadLabsData();
                  break;
                case 'reload_all':
                  _showReloadAllConfirmation();
                  break;
                case 'delete_all':
                  _showDeleteAllConfirmation();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'export', child: Text('Export FHIR')),
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(
                value: 'reload_all',
                child: Text(
                  'Reload All Reports',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Text(
                  'Delete All Lab Data',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Obx(() => FloatingActionButton.extended(
        onPressed: controller.uploadStatus.value == Status.LOADING
            ? null
            : _showAddLabOptions,
        icon: controller.uploadStatus.value == Status.LOADING
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.add),
        label: Text("Add Lab"),
        backgroundColor: Colors.blue,
      )),
      body: RefreshIndicator(
        onRefresh: controller.loadLabsData,
        child: Obx(() {
          if (controller.requestStatus.value == Status.LOADING) {
            return _buildLoadingState();
          }

          return CustomScrollView(
            slivers: [
              // Labs Summary
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: LabsSummaryCard(summary: controller.labsSummary.value),
                ),
              ),

              // Health Insights
              Obx(() {
                if (controller.healthInsights.isNotEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: HealthInsightsSection(
                        insights: controller.healthInsights,
                        onDismiss: controller.dismissInsight,
                      ),
                    ),
                  );
                }
                return SliverToBoxAdapter(child: SizedBox.shrink());
              }),

              // Due for Repeat Recommendations
              Obx(() {
                final dueForRepeat = controller.biomarkersDueForRepeat;
                if (dueForRepeat.isNotEmpty) {
                  return SliverToBoxAdapter(
                    child: DueRepeatSection(
                      dueForRepeat: dueForRepeat,
                      onTapBiomarker: (biomarker) => _navigateToBiomarkerDetail(biomarker),
                    ),
                  );
                }
                return SliverToBoxAdapter(child: SizedBox.shrink());
              }),

              // Category Tabs
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryTabsDelegate(
                  controller: controller,
                  tabController: _categoryTabController,
                ),
              ),

              // Biomarkers List
              Obx(() => _buildBiomarkersList()),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _shimmerCard(height: 160), // Summary card
          SizedBox(height: 16),
          _shimmerCard(height: 120), // Insights
          SizedBox(height: 16),
          ...List.generate(5, (index) => _shimmerCard()), // Biomarker cards
        ],
      ),
    );
  }

  Widget _buildBiomarkersList() {
    final filteredBiomarkers = controller.filteredBiomarkers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (filteredBiomarkers.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.science_outlined, size: 80, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              SizedBox(height: 16),
              Text(
                "No biomarkers found",
                style: TextStyle(fontSize: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              SizedBox(height: 8),
              Text(
                "Upload lab reports or add measurements manually",
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by category if showing all categories
    if (controller.selectedCategory.value == 'all') {
      final groupedBiomarkers = controller.biomarkersByCategory;

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final categories = groupedBiomarkers.keys.toList();
            final category = categories[index];
            final biomarkers = groupedBiomarkers[category]!;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ),
                  
                  // Biomarkers in this category
                  ...biomarkers.map((biomarker) => 
                    BiomarkerCard(
                      biomarker: biomarker,
                      onTap: () => _navigateToBiomarkerDetail(biomarker),
                      onAddValue: () => _showAddValueDialog(biomarker),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                ],
              ),
            );
          },
          childCount: groupedBiomarkers.length,
        ),
      );
    } else {
      // Show flat list for specific category
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final biomarker = filteredBiomarkers[index];
              return BiomarkerCard(
                biomarker: biomarker,
                onTap: () => _navigateToBiomarkerDetail(biomarker),
                onAddValue: () => _showAddValueDialog(biomarker),
              );
            },
            childCount: filteredBiomarkers.length,
          ),
        ),
      );
    }
  }

  void _showAddLabOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add Lab Data",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Upload document
            _addOptionTile(
              icon: Icons.upload_file,
              title: "Upload Lab Report",
              subtitle: "PDF, photo of lab results",
              onTap: () {
                Navigator.pop(context);
                controller.uploadLabDocument();
              },
            ),
            
            // Camera scan
            _addOptionTile(
              icon: Icons.camera_alt,
              title: "Scan with Camera",
              subtitle: "Take photo of lab results",
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement camera scan
              },
            ),
            
            // Manual entry
            _addOptionTile(
              icon: Icons.edit,
              title: "Manual Entry",
              subtitle: "Enter values manually",
              onTap: () {
                Navigator.pop(context);
                _showManualEntryDialog();
              },
            ),
            
            SizedBox(height: 20),
            
            // Disclaimer
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "For informational purposes only. Not a substitute for professional medical advice.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _addOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Biomarkers'),
        content: TextField(
          onChanged: controller.updateSearchQuery,
          decoration: InputDecoration(
            hintText: 'Enter biomarker name...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.updateSearchQuery('');
              Navigator.pop(context);
            },
            child: Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => _ManualEntryDialog(controller: controller),
    );
  }

  void _showAddValueDialog(biomarker) {
    showDialog(
      context: context,
      builder: (context) => _AddValueDialog(
        biomarker: biomarker,
        controller: controller,
      ),
    );
  }

  void _navigateToBiomarkerDetail(biomarker) {
    Get.toNamed('/biomarker-detail', arguments: biomarker);
  }

  void _showDeleteAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.red.shade700, size: 28),
            SizedBox(width: 8),
            Text('Delete All Lab Data?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• All biomarker measurements'),
            Text('• All uploaded lab reports'),
            Text('• All medical documents'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteAllLabData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showReloadAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.refresh, color: Colors.orange.shade700, size: 28),
            SizedBox(width: 8),
            Text('Reload All Reports?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Re-analyze all uploaded lab reports'),
            Text('• Extract biomarker data again with latest AI'),
            Text('• Replace existing biomarker measurements'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This may take a few minutes depending on the number of reports.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              controller.reloadAllReports();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Reload All'),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabsDelegate extends SliverPersistentHeaderDelegate {
  final LabsController controller;
  final TabController tabController;

  _CategoryTabsDelegate({
    required this.controller,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return CategoryTabs(
      controller: controller,
      tabController: tabController,
    );
  }

  @override
  double get maxExtent => 100.0;

  @override
  double get minExtent => 100.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _ManualEntryDialog extends StatefulWidget {
  final LabsController controller;

  const _ManualEntryDialog({required this.controller});

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _valueController = TextEditingController();
  final _unitController = TextEditingController();
  final _notesController = TextEditingController();
  
  BiomarkerDefinition? _selectedBiomarker;
  DateTime _collectedDate = DateTime.now();
  List<BiomarkerDefinition> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Biomarker Measurement'),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Biomarker Search
                Text('Select Biomarker', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for biomarker (e.g., Glucose, Cholesterol)',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    suffixIcon: _isSearching ? 
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  ),
                  onChanged: _searchBiomarkers,
                  validator: (value) {
                    if (_selectedBiomarker == null) {
                      return 'Please select a biomarker';
                    }
                    return null;
                  },
                ),
                
                // Search Results
                if (_searchResults.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    constraints: BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final biomarker = _searchResults[index];
                        return ListTile(
                          dense: true,
                          title: Text(biomarker.name),
                          subtitle: Text(biomarker.category),
                          onTap: () => _selectBiomarker(biomarker),
                        );
                      },
                    ),
                  ),
                ],
                
                // Selected Biomarker
                if (_selectedBiomarker != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBiomarker!.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _selectedBiomarker!.category,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (_selectedBiomarker!.preferredUnit != null)
                          Text(
                            'Preferred Unit: ${_selectedBiomarker!.preferredUnit}',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                          ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 16),
                
                // Value Input
                Text('Measurement Value', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _valueController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Enter value',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a value';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        decoration: InputDecoration(
                          hintText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Unit required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Collection Date
                Text('Collection Date', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 8),
                        Text(DateFormat('MMM dd, yyyy').format(_collectedDate)),
                        Spacer(),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Notes (Optional)
                Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any additional notes or context...',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Safety Disclaimer
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For tracking purposes only. Always consult your healthcare provider for medical decisions.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitMeasurement,
          child: Text('Add Measurement'),
        ),
      ],
    );
  }

  void _searchBiomarkers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults.clear());
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await BiomarkersRepository().searchBiomarkers(query);
      if (response.status == Status.COMPLETED && response.data != null) {
        if (mounted) {
          setState(() {
            _searchResults = response.data!;
            _isSearching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _searchResults.clear();
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
        });
      }
    }
  }

  void _selectBiomarker(BiomarkerDefinition biomarker) {
    setState(() {
      _selectedBiomarker = biomarker;
      _searchController.text = biomarker.name;
      _searchResults.clear();
      
      // Pre-fill unit if available
      if (biomarker.preferredUnit != null) {
        _unitController.text = biomarker.preferredUnit!;
      }
    });
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _collectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() => _collectedDate = date);
    }
  }

  void _submitMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    final value = double.parse(_valueController.text);
    final unit = _unitController.text;
    final notes = _notesController.text.isNotEmpty ? _notesController.text : null;

    Navigator.pop(context);

    await widget.controller.addManualObservation(
      biomarkerId: _selectedBiomarker!.id,
      value: value,
      unit: unit,
      collectedAt: _collectedDate,
      notes: notes,
    );
  }
}

class _AddValueDialog extends StatefulWidget {
  final BiomarkerWithTrend biomarker;
  final LabsController controller;

  const _AddValueDialog({
    required this.biomarker,
    required this.controller,
  });

  @override
  State<_AddValueDialog> createState() => _AddValueDialogState();
}

class _AddValueDialogState extends State<_AddValueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _collectedDate = DateTime.now();
  String _unit = '';

  @override
  void initState() {
    super.initState();
    
    // Pre-fill unit from latest observation or biomarker definition
    if (widget.biomarker.latestObservation?.unitOriginal != null) {
      _unit = widget.biomarker.latestObservation!.unitOriginal!;
    } else if (widget.biomarker.definition.preferredUnit != null) {
      _unit = widget.biomarker.definition.preferredUnit!;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Value for'),
          Text(
            widget.biomarker.definition.name,
            style: TextStyle(fontSize: 16, color: Colors.blue.shade700),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status
              if (widget.biomarker.hasData) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                        widget.biomarker.latestObservation!.displayValue,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'on ${DateFormat('MMM dd, yyyy').format(widget.biomarker.latestObservation!.collectedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
              
              // Reference Range
              if (widget.biomarker.definition.referenceRanges.isNotEmpty) ...[
                Text('Reference Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                ...widget.biomarker.definition.referenceRanges.map((range) => 
                  Text(
                    '${range.low ?? '?'} - ${range.high ?? '?'} ${range.unit}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                  ),
                ),
                SizedBox(height: 16),
              ],
              
              // Value Input
              Text('New Value', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Enter value',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a value';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_unit.isNotEmpty ? _unit : 'Unit'),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Collection Date
              Text('Collection Date', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16),
                      SizedBox(width: 8),
                      Text(DateFormat('MMM dd, yyyy').format(_collectedDate)),
                      Spacer(),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              // Notes (Optional)
              Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add context or notes...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitValue,
          child: Text('Add Value'),
        ),
      ],
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _collectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() => _collectedDate = date);
    }
  }

  void _submitValue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unit is required')),
      );
      return;
    }

    final value = double.parse(_valueController.text);
    final notes = _notesController.text.isNotEmpty ? _notesController.text : null;

    Navigator.pop(context);

    await widget.controller.addManualObservation(
      biomarkerId: widget.biomarker.definition.id,
      value: value,
      unit: _unit,
      collectedAt: _collectedDate,
      notes: notes,
    );
  }
}