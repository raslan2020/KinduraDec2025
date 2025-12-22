import 'package:flutter/material.dart';
import 'package:kindura_ai/models/medical_reports/medical_report.dart';
import 'package:intl/intl.dart';

class DocumentCard extends StatelessWidget {
  final MedicalDocument document;

  const DocumentCard({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Document type icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getColorForDocumentType(document.documentType ?? '').withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForDocumentType(document.documentType ?? ''),
              color: _getColorForDocumentType(document.documentType ?? ''),
              size: 24,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title ?? 'Untitled Document',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 4),
                
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getDisplayNameForDocumentType(document.documentType ?? ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (document.fileName != null && document.fileName!.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          document.fileName!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                
                if (document.description != null && document.description!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    document.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          
          // Date and actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                document.uploadedAt != null
                    ? DateFormat('MMM dd').format(document.uploadedAt!)
                    : 'No date',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                document.uploadedAt != null
                    ? DateFormat('HH:mm').format(document.uploadedAt!)
                    : '',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
              
              SizedBox(height: 8),
              
              // Action button
              GestureDetector(
                onTap: () {
                  _showDocumentActions(context);
                },
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForDocumentType(String type) {
    switch (type) {
      case 'lab_report':
        return Icons.science;
      case 'prescription':
        return Icons.medication;
      case 'scan':
        return Icons.scanner;
      case 'x_ray':
        return Icons.medical_information;
      default:
        return Icons.description;
    }
  }

  Color _getColorForDocumentType(String type) {
    switch (type) {
      case 'lab_report':
        return Colors.blue;
      case 'prescription':
        return Colors.green;
      case 'scan':
        return Colors.orange;
      case 'x_ray':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayNameForDocumentType(String type) {
    switch (type) {
      case 'lab_report':
        return 'Lab Report';
      case 'prescription':
        return 'Prescription';
      case 'scan':
        return 'Scan';
      case 'x_ray':
        return 'X-Ray';
      default:
        return 'Document';
    }
  }

  void _showDocumentActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: Colors.blue),
              title: Text('View Document'),
              onTap: () {
                Navigator.pop(context);
                // Handle view document
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green),
              title: Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // Handle share
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: Colors.orange),
              title: Text('Download'),
              onTap: () {
                Navigator.pop(context);
                // Handle download
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle delete
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}