import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/screens/home/home_controller.dart';
import 'package:kindura_ai/utils/performance_monitor.dart';
import 'package:kindura_ai/utils/utils.dart';

/// Debug widget for viewing performance logs and metrics
class PerformanceDebugWidget extends StatefulWidget {
  const PerformanceDebugWidget({super.key});

  @override
  State<PerformanceDebugWidget> createState() => _PerformanceDebugWidgetState();
}

class _PerformanceDebugWidgetState extends State<PerformanceDebugWidget> {
  final PerformanceMonitor _monitor = PerformanceMonitor();
  bool _showLogs = true;
  bool _showMetrics = false;
  String _selectedCategory = 'ALL';
  
  final List<String> _categories = [
    'ALL',
    'API_CALL_START',
    'API_CALL_END', 
    'LIVEKIT_EVENT',
    'TRANSCRIPTION',
    'VOICE_TRIGGER',
    'ERROR',
    'PERFORMANCE_METRIC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Performance Monitor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tab buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          _showLogs = true;
                          _showMetrics = false;
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showLogs ? Colors.blue : Colors.grey.shade300,
                          foregroundColor: _showLogs ? Colors.white : Colors.black,
                        ),
                        child: const Text('Recent Logs'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          _showLogs = false;
                          _showMetrics = true;
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showMetrics ? Colors.blue : Colors.grey.shade300,
                          foregroundColor: _showMetrics ? Colors.white : Colors.black,
                        ),
                        child: const Text('Summary'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Category filter and action buttons
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _copyLogs,
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy logs to clipboard',
                    ),
                    IconButton(
                      onPressed: _clearLogs,
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Clear all logs',
                    ),
                    IconButton(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _showLogs ? _buildLogsView() : _buildMetricsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsView() {
    final logs = _getFilteredLogs();
    
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No logs available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final level = log['level'] as String;
    final timestamp = log['timestamp'] as String;
    final message = log['message'] as String;
    final data = log['data'] as Map<String, dynamic>;
    
    Color levelColor = Colors.grey;
    IconData levelIcon = Icons.info;
    
    switch (level) {
      case 'ERROR':
        levelColor = Colors.red;
        levelIcon = Icons.error;
        break;
      case 'API_CALL_START':
      case 'API_CALL_END':
        levelColor = Colors.green;
        levelIcon = Icons.api;
        break;
      case 'LIVEKIT_EVENT':
        levelColor = Colors.purple;
        levelIcon = Icons.wifi;
        break;
      case 'TRANSCRIPTION':
        levelColor = Colors.orange;
        levelIcon = Icons.mic;
        break;
      case 'PERFORMANCE_METRIC':
        levelColor = Colors.blue;
        levelIcon = Icons.speed;
        break;
      case 'VOICE_TRIGGER':
        levelColor = Colors.teal;
        levelIcon = Icons.voice_chat;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(levelIcon, color: levelColor, size: 20),
        title: Text(
          message,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${DateTime.parse(timestamp).toLocal().toString().split('.')[0]} • $level',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          if (data.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsView() {
    final summary = _monitor.getPerformanceSummary();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard('API Calls', summary['total_api_calls'].toString(), Icons.api, Colors.green),
        _buildSummaryCard('Errors', summary['total_errors'].toString(), Icons.error, Colors.red),
        _buildSummaryCard('LiveKit Events', summary['total_livekit_events'].toString(), Icons.wifi, Colors.purple),
        _buildSummaryCard(
          'Avg API Response',
          '${summary['average_api_response_time'].toStringAsFixed(0)}ms',
          Icons.speed,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Error Rate',
          '${(summary['error_rate'] * 100).toStringAsFixed(1)}%',
          Icons.warning,
          Colors.orange,
        ),
        
        const SizedBox(height: 16),
        const Text('Performance Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        ...(summary['performance_alerts'] as List<String>).map((alert) {
          return Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: Text(alert),
            ),
          );
        }).toList(),
        
        if ((summary['performance_alerts'] as List).isEmpty)
          Card(
            color: Colors.green.shade50,
            child: const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('No performance alerts'),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredLogs() {
    final logs = _monitor.getRecentLogs(100);
    
    if (_selectedCategory == 'ALL') {
      return logs;
    }
    
    return logs.where((log) => log['level'] == _selectedCategory).toList();
  }

  void _copyLogs() {
    final logs = _getFilteredLogs();
    final logsText = logs.map((log) {
      return '${log['timestamp']} [${log['level']}] ${log['message']}\n${log['data']}\n';
    }).join('\n');
    
    Clipboard.setData(ClipboardData(text: logsText));
    Util.Snack_Bar('Success', 'Logs copied to clipboard');
  }

  void _clearLogs() {
    _monitor.clearLogs();
    setState(() {});
    Util.Snack_Bar('Success', 'Logs cleared');
  }
}

/// Extension to easily show the debug widget
extension PerformanceDebugExtension on GetInterface {
  void showPerformanceDebug() {
    Get.bottomSheet(
      const PerformanceDebugWidget(),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
    );
  }
}