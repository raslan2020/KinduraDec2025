import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickAddDialog extends StatefulWidget {
  final String title;
  final String type;
  final List<String> fields;
  final Function(Map<String, double>) onSubmit;

  const QuickAddDialog({
    super.key,
    required this.title,
    required this.type,
    required this.fields,
    required this.onSubmit,
  });

  static QuickAddDialog bloodPressure({required Function(double, double) onSubmit}) {
    return QuickAddDialog(
      title: "Add Blood Pressure",
      type: "blood_pressure",
      fields: ["Systolic", "Diastolic"],
      onSubmit: (values) {
        onSubmit(values["Systolic"]!, values["Diastolic"]!);
      },
    );
  }

  static QuickAddDialog heartRate({required Function(double) onSubmit}) {
    return QuickAddDialog(
      title: "Add Heart Rate",
      type: "heart_rate",
      fields: ["Heart Rate"],
      onSubmit: (values) {
        onSubmit(values["Heart Rate"]!);
      },
    );
  }

  static QuickAddDialog weight({required Function(double) onSubmit}) {
    return QuickAddDialog(
      title: "Add Weight",
      type: "weight",
      fields: ["Weight"],
      onSubmit: (values) {
        onSubmit(values["Weight"]!);
      },
    );
  }

  static QuickAddDialog bloodSugar({required Function(double) onSubmit}) {
    return QuickAddDialog(
      title: "Add Blood Sugar",
      type: "blood_sugar",
      fields: ["Blood Sugar"],
      onSubmit: (values) {
        onSubmit(values["Blood Sugar"]!);
      },
    );
  }

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, double> _values = {};

  @override
  void initState() {
    super.initState();
    for (String field in widget.fields) {
      _controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_getIconForType(widget.type), color: _getColorForType(widget.type)),
          SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (String field in widget.fields) ...[
              TextFormField(
                controller: _controllers[field],
                decoration: InputDecoration(
                  labelText: field,
                  suffixText: _getUnitForField(field),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter $field';
                  }
                  double? parsedValue = double.tryParse(value);
                  if (parsedValue == null) {
                    return 'Please enter a valid number';
                  }
                  if (!_isValidRange(field, parsedValue)) {
                    return 'Please enter a valid ${field.toLowerCase()}';
                  }
                  return null;
                },
              ),
              if (field != widget.fields.last) SizedBox(height: 16),
            ],
            
            if (widget.type == "blood_pressure") ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
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
                        "Normal: <120/80 mmHg",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getColorForType(widget.type),
            foregroundColor: Colors.white,
          ),
          child: Text('Add'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      for (String field in widget.fields) {
        _values[field] = double.parse(_controllers[field]!.text);
      }
      widget.onSubmit(_values);
      Navigator.pop(context);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'blood_pressure':
        return Icons.favorite;
      case 'heart_rate':
        return Icons.monitor_heart;
      case 'weight':
        return Icons.scale;
      case 'blood_sugar':
        return Icons.bloodtype;
      default:
        return Icons.health_and_safety;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'blood_pressure':
        return Colors.red;
      case 'heart_rate':
        return Colors.pink;
      case 'weight':
        return Colors.green;
      case 'blood_sugar':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getUnitForField(String field) {
    switch (field) {
      case 'Systolic':
      case 'Diastolic':
        return 'mmHg';
      case 'Heart Rate':
        return 'bpm';
      case 'Weight':
        return 'kg';
      case 'Blood Sugar':
        return 'mg/dL';
      default:
        return '';
    }
  }

  bool _isValidRange(String field, double value) {
    switch (field) {
      case 'Systolic':
        return value >= 50 && value <= 250;
      case 'Diastolic':
        return value >= 30 && value <= 150;
      case 'Heart Rate':
        return value >= 30 && value <= 250;
      case 'Weight':
        return value >= 20 && value <= 300;
      case 'Blood Sugar':
        return value >= 20 && value <= 600;
      default:
        return true;
    }
  }
}