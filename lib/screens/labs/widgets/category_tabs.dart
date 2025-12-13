import 'package:flutter/material.dart';
import 'package:kindura_ai/screens/labs/labs_controller.dart';
import 'package:get/get.dart';

class CategoryTabs extends StatelessWidget {
  final LabsController controller;
  final TabController tabController;

  const CategoryTabs({
    super.key,
    required this.controller,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: Colors.grey.shade50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter row
          SizedBox(
            height: 50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Obx(() => Row(
                children: [
                  // Latest filter toggle (default)
                  FilterChip(
                    label: Text('Latest'),
                    selected: controller.showLatestFirst.value,
                    onSelected: (_) => controller.toggleLatestFilter(),
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: controller.showLatestFirst.value
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(width: 8),

                  // Abnormal filter toggle
                  FilterChip(
                    label: Text('Abnormal'),
                    selected: controller.showOnlyAbnormal.value,
                    onSelected: (_) => controller.toggleAbnormalFilter(),
                    selectedColor: Colors.orange.shade100,
                    checkmarkColor: Colors.orange.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: controller.showOnlyAbnormal.value
                          ? Colors.orange.shade700
                          : Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(width: 8),

                  // Due for Repetition filter toggle
                  FilterChip(
                    label: Text('Due for Repeat'),
                    selected: controller.showDueForRepetition.value,
                    onSelected: (_) => controller.toggleDueForRepetitionFilter(),
                    selectedColor: Colors.purple.shade100,
                    checkmarkColor: Colors.purple.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: controller.showDueForRepetition.value
                          ? Colors.purple.shade700
                          : Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(width: 16),

                  // Results count
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${controller.filteredBiomarkers.length} results',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              )),
            ),
          ),

          // Category tabs
          SizedBox(
            height: 44,
            child: Obx(() {
              final categories = _buildCategoryList();

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: categories.length,
                separatorBuilder: (context, index) => SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = controller.selectedCategory.value == category['key'];

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => controller.setCategory(category['key']),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category['name'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),

                            if (category['count'] != null) ...[
                              SizedBox(width: 6),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  category['count'].toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildCategoryList() {
    final categories = <Map<String, dynamic>>[];
    
    // Add "All" category
    categories.add({
      'key': 'all',
      'name': 'All',
      'count': controller.biomarkers.length,
    });
    
    // Add specific categories with counts
    final categoryGroups = [
      {'key': 'cardiovascular', 'name': 'Heart Health', 'icon': Icons.favorite},
      {'key': 'metabolic', 'name': 'Metabolism', 'icon': Icons.speed},
      {'key': 'liver', 'name': 'Liver', 'icon': Icons.local_hospital},
      {'key': 'kidney', 'name': 'Kidney', 'icon': Icons.water_drop},
      {'key': 'lipids', 'name': 'Lipids', 'icon': Icons.opacity},
      {'key': 'diabetes', 'name': 'Diabetes', 'icon': Icons.bloodtype},
      {'key': 'thyroid', 'name': 'Thyroid', 'icon': Icons.psychology},
      {'key': 'inflammation', 'name': 'Inflammation', 'icon': Icons.healing},
      {'key': 'nutrition', 'name': 'Vitamins', 'icon': Icons.eco},
    ];
    
    for (final group in categoryGroups) {
      final count = controller.biomarkers
          .where((b) => b.definition.category.toLowerCase() == group['key'])
          .length;
      
      if (count > 0) {
        categories.add({
          'key': group['key'],
          'name': group['name'],
          'count': count,
          'icon': group['icon'],
        });
      }
    }
    
    return categories;
  }
}