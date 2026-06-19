import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.healing,
                color: const Color(0xFFFF9800),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '治疗项目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF9800),
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
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF9800)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onSubmitted: _addCustomTreatment,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  value: _selectedSuggestion,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  focusColor: Colors.transparent,
                  decoration: InputDecoration(
                    labelText: '选择已有项目',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF9800)),
                    ),
                  ),
                  hint: const Text('暂无'),
                  items:
                      widget.suggestions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                color: Colors.grey.shade600,
              ),
            ),
          ],
          if (_localSelectedTreatments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF9800).withOpacity(0.2),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    _localSelectedTreatments
                        .map(
                          (treatment) => InputChip(
                            label: Text(
                              treatment,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFF9800),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onDeleted: () => _removeTreatment(treatment),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFFFF9800),
                            ),
                            backgroundColor: const Color(0xFFFF9800)
                                .withOpacity(0.08),
                            side: BorderSide(
                              color: const Color(0xFFFF9800).withOpacity(0.25),
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
