import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

class TreatmentItemsInput extends StatefulWidget {
  final TextEditingController controller;
  final List<String> selectedTreatments;
  final List<String> suggestions;
  final Function(List<String>) onChanged;

  const TreatmentItemsInput({
    super.key,
    required this.controller,
    required this.selectedTreatments,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<TreatmentItemsInput> createState() => TreatmentItemsInputState();
}

class TreatmentItemsInputState extends State<TreatmentItemsInput> {
  String? _selectedSuggestion;

  void _addTreatment(String treatment) {
    final trimmed = treatment.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final treatments = List<String>.from(widget.selectedTreatments);
    if (!treatments.contains(trimmed)) {
      treatments.add(trimmed);
      widget.onChanged(treatments);
    }

    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactLayout = constraints.maxWidth < 420;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompactLayout) ...[
              _buildModernTextField(
                controller: widget.controller,
                hint: '输入治疗项目',
                icon: Icons.healing_rounded,
              ),
              const SizedBox(height: 12),
              _buildSuggestionDropdown(),
            ] else
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildModernTextField(
                      controller: widget.controller,
                      hint: '输入治疗项目',
                      icon: Icons.healing_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 4, child: _buildSuggestionDropdown()),
                ],
              ),
            if (widget.selectedTreatments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    widget.selectedTreatments.map((treatment) {
                      return Chip(
                        label: Text(treatment),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            final treatments = List<String>.from(
                              widget.selectedTreatments,
                            )..remove(treatment);
                            widget.onChanged(treatments);
                            widget.controller.clear();
                          });
                        },
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.1,
                        ),
                        labelStyle: const TextStyle(
                          color: AppTheme.primaryText,
                        ),
                      );
                    }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSuggestionDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSuggestion,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '选择已有项目',
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      hint: const Text('暂无', overflow: TextOverflow.ellipsis),
      items:
          widget.suggestions
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged:
          widget.suggestions.isEmpty
              ? null
              : (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedSuggestion = null;
                  _addTreatment(value);
                });
              },
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onFieldSubmitted: (_) {
          setState(() {
            _addTreatment(controller.text);
          });
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.secondaryText),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(fontSize: 16, color: AppTheme.primaryText),
      ),
    );
  }
}
