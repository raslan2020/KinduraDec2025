import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/report_generation_service.dart';
import '../res/colors/app_color.dart';

/// A floating progress indicator that shows report generation status.
/// Stays visible during navigation and can be dismissed when complete.
class ReportProgressOverlay extends StatelessWidget {
  const ReportProgressOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the service - it should be registered in main.dart
    if (!Get.isRegistered<ReportGenerationService>()) {
      return const SizedBox.shrink();
    }

    final service = Get.find<ReportGenerationService>();

    return Obx(() {
      if (!service.isGenerating.value && service.status.value != 'completed') {
        return const SizedBox.shrink();
      }

      return Positioned(
        bottom: 100,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: _getBackgroundColor(service.status.value),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _onTap(service),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildIcon(service.status.value),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getTitle(service),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (service.isGenerating.value) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: service.progress.value / 100,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${service.progress.value}% complete',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (service.status.value == 'completed')
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => service.cancelPolling(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Color _getBackgroundColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green.shade600;
      case 'failed':
        return Colors.red.shade600;
      default:
        return AppColor.primaryColor;
    }
  }

  Widget _buildIcon(String status) {
    switch (status) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.white, size: 28);
      case 'failed':
        return const Icon(Icons.error, color: Colors.white, size: 28);
      default:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
    }
  }

  String _getTitle(ReportGenerationService service) {
    final type = _formatReportType(service.currentReportType.value);

    switch (service.status.value) {
      case 'completed':
        return '$type Report Ready';
      case 'failed':
        return '$type Report Failed';
      default:
        return 'Generating $type Report...';
    }
  }

  String _formatReportType(String type) {
    switch (type.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return type;
    }
  }

  void _onTap(ReportGenerationService service) {
    if (service.status.value == 'completed' && service.activeReportId.value != null) {
      // Navigate to reports screen
      Get.toNamed('/kindura_reports', arguments: {
        'report_id': service.activeReportId.value,
      });
      service.cancelPolling(); // Clear the overlay
    }
  }
}

/// A wrapper widget that adds the report progress overlay to any screen.
/// Use this as the body of your Scaffold to show the overlay.
class WithReportProgressOverlay extends StatelessWidget {
  final Widget child;

  const WithReportProgressOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const ReportProgressOverlay(),
      ],
    );
  }
}
