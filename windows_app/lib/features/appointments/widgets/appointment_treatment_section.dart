import 'package:flutter/material.dart';

class TreatmentSectionWidget extends StatefulWidget {
  final List<String> selectedTreatments;
  final TextEditingController treatmentTypeController;
  final VoidCallback onShowTreatmentSelectionDialog;
  final ValueChanged<List<String>> onTreatmentsChanged;

  const TreatmentSectionWidget({
    Key? key,
    required this.selectedTreatments,
    required this.treatmentTypeController,
    required this.onShowTreatmentSelectionDialog,
    required this.onTreatmentsChanged,
  }) : super(key: key);

  @override
  State<TreatmentSectionWidget> createState() => _TreatmentSectionWidgetState();
}

class _TreatmentSectionWidgetState extends State<TreatmentSectionWidget> {
  late List<String> _localSelectedTreatments;
  late TextEditingController _localController;

  @override
  void initState() {
    super.initState();
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
      _updateTreatmentTypeController();
      widget.onTreatmentsChanged(_localSelectedTreatments);
    });
  }

  void _updateTreatmentTypeController() {
    if (_localSelectedTreatments.isEmpty) {
      _localController.text = '';
    } else {
      _localController.text = _localSelectedTreatments.join('、');
    }
  }

  void _removeTreatment(String treatment) {
    setState(() {
      _localSelectedTreatments.remove(treatment);
      _updateTreatmentTypeController();
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
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF9800),
                      Color(0xFFFFB74D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    '选择',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: widget.onShowTreatmentSelectionDialog,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
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
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF9800),
                      Color(0xFFFFB74D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9800).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _addCustomTreatment(_localController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    '添加',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_localSelectedTreatments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xFFFF9800),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '已选治疗项目:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _localSelectedTreatments
                        .map((treatment) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF9800).withOpacity(0.1),
                                    const Color(0xFFFFB74D).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFF9800).withOpacity(0.3),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    _removeTreatment(treatment);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          treatment,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFFFF9800),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.close,
                                          size: 12,
                                          color: const Color(0xFFFF9800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
