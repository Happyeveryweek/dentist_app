import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/widgets/compact_dropdown_form_field.dart';

class TreatmentSectionWidget extends StatefulWidget {
  final List<String> selectedTreatments;
  final TextEditingController treatmentTypeController;
  final List<String> suggestions;
  final ValueChanged<List<String>> onTreatmentsChanged;

  const TreatmentSectionWidget({
    Key? key,
    required this.selectedTreatments,
    required this.treatmentTypeController,
    required this.suggestions,
    required this.onTreatmentsChanged,
  }) : super(key: key);

  @override
  State<TreatmentSectionWidget> createState() => _TreatmentSectionWidgetState();
}

class _TreatmentSectionWidgetState extends State<TreatmentSectionWidget> {
  late List<String> _localSelectedTreatments;
  late TextEditingController _localController;
  String? _selectedSuggestion;

  @override
  void initState() {
    super.initState();
    _localSelectedTreatments = List<String>.from(widget.selectedTreatments);
    _localController = widget.treatmentTypeController;
  }

  @override
  void didUpdateWidget(covariant TreatmentSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _localSelectedTreatments = List<String>.from(widget.selectedTreatments);
    _localController = widget.treatmentTypeController;
  }

  void _addCustomTreatment(String treatment) {
    String trimmedTreatment = treatment.trim();
    if (trimmedTreatment.isEmpty) return;

    setState(() {
      if (!_localSelectedTreatments.contains(trimmedTreatment)) {
        _localSelectedTreatments.add(trimmedTreatment);
      }
      _localController.clear();
      widget.onTreatmentsChanged(_localSelectedTreatments);
    });
  }

  void _removeTreatment(String treatment) {
    setState(() {
      _localSelectedTreatments.remove(treatment);
      widget.onTreatmentsChanged(_localSelectedTreatments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.healing,
                color: tokens.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '治疗项目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  controller: _localController,
                  decoration: InputDecoration(
                    hintText: '输入治疗项目',
                    hintStyle: TextStyle(color: tokens.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.warning),
                    ),
                    filled: true,
                    fillColor: tokens.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  onSubmitted: _addCustomTreatment,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: CompactDropdownFormField<String>(
                  value: _selectedSuggestion,
                  menuMaxHeight: 188,
                  decoration: InputDecoration(
                    labelText: '选择已有项目',
                    filled: true,
                    fillColor: tokens.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: tokens.warning),
                    ),
                  ),
                  items: widget.suggestions
                      .map(
                        (item) => CompactDropdownItem<String>(
                          value: item,
                          child: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  enabled: widget.suggestions.isNotEmpty,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedSuggestion = null;
                      _addCustomTreatment(value);
                    });
                  },
                ),
              ),
            ],
          ),
          if (_localController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '输入后按回车，或直接保存时自动带入',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textMuted,
              ),
            ),
          ],
          if (_localSelectedTreatments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tokens.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _localSelectedTreatments
                    .map(
                      (treatment) => InputChip(
                        label: Text(
                          treatment,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onDeleted: () => _removeTreatment(treatment),
                        deleteIcon: Icon(
                          Icons.close,
                          size: 14,
                          color: tokens.warning,
                        ),
                        backgroundColor: tokens.warning.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: tokens.warning.withValues(alpha: 0.25),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
