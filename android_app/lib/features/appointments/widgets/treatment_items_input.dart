import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

class TreatmentItemsInput extends StatefulWidget {
  final TextEditingController controller;
  final List<String> selectedTreatments;
  final Function(List<String>) onChanged;

  const TreatmentItemsInput({
    required this.controller,
    required this.selectedTreatments,
    required this.onChanged,
  });

  @override
  State<TreatmentItemsInput> createState() => TreatmentItemsInputState();
}

class TreatmentItemsInputState extends State<TreatmentItemsInput> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: widget.controller,
                hint: '输入治疗项目',
                icon: Icons.healing_rounded,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (widget.controller.text.isNotEmpty) {
                  setState(() {
                    if (!widget.selectedTreatments.contains(widget.controller.text)) {
                      widget.selectedTreatments.add(widget.controller.text);
                    }
                    widget.controller.clear();
                    widget.onChanged(widget.selectedTreatments);
                  });
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primaryColor,
            ),
          ],
        ),
        if (widget.selectedTreatments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedTreatments.map((treatment) {
              return Chip(
                label: Text(treatment),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    widget.selectedTreatments.remove(treatment);
                    widget.onChanged(widget.selectedTreatments);
                  });
                },
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                labelStyle: const TextStyle(color: AppTheme.primaryText),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.secondaryText),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppTheme.primaryText,
        ),
      ),
    );
  }
}
