import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';

/// 疾病选择组件
class DiseaseSelectionWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, List<String>> diseases;
  final Set<String> selectedDiseases;
  final TextEditingController customController;
  final Function(Set<String>) onSelectionChanged;
  final bool hasEditPermission;
  final Widget Function({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines,
    bool enabled,
    String? Function(String?)? validator,
  }) buildInputField;

  const DiseaseSelectionWidget({
    Key? key,
    required this.title,
    required this.icon,
    required this.diseases,
    required this.selectedDiseases,
    required this.customController,
    required this.onSelectionChanged,
    required this.hasEditPermission,
    required this.buildInputField,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 疾病类型网格
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DentalColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.divider,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 疾病类型选择
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: diseases.keys.map((diseaseType) {
                  final isSelected = selectedDiseases
                      .any((selected) => selected.startsWith(diseaseType));

                  return FilterChip(
                    label: Text(diseaseType),
                    selected: isSelected,
                    onSelected: hasEditPermission
                        ? (selected) {
                            final newSelected =
                                Set<String>.from(selectedDiseases);
                            if (selected) {
                              newSelected.add(diseaseType);
                            } else {
                              newSelected.removeWhere(
                                  (item) => item.startsWith(diseaseType));
                            }
                            onSelectionChanged(newSelected);
                          }
                        : null,
                    backgroundColor: hasEditPermission
                        ? DentalColors.surface
                        : Colors.grey.shade200,
                    selectedColor: DentalColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: DentalColors.primary,
                    labelStyle: TextStyle(
                      color: hasEditPermission
                          ? (isSelected
                              ? DentalColors.primary
                              : DentalColors.onSurface)
                          : Colors.grey,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),

              // 显示选中疾病类型的子类型
              ...diseases.entries
                  .where((entry) => selectedDiseases
                      .any((selected) => selected.startsWith(entry.key)))
                  .map((entry) => DiseaseSubTypeSelectionWidget(
                        diseaseType: entry.key,
                        subTypes: entry.value,
                        selectedDiseases: selectedDiseases,
                        onSelectionChanged: onSelectionChanged,
                        hasEditPermission: hasEditPermission,
                      )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 其他疾病输入框
        buildInputField(
          controller: customController,
          label: '其他${title.replaceAll('既往史', '')}',
          hint: '请输入其他疾病情况',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
          enabled: hasEditPermission,
        ),
      ],
    );
  }
}

/// 疾病子类型选择组件
class DiseaseSubTypeSelectionWidget extends StatelessWidget {
  final String diseaseType;
  final List<String> subTypes;
  final Set<String> selectedDiseases;
  final Function(Set<String>) onSelectionChanged;
  final bool hasEditPermission;

  const DiseaseSubTypeSelectionWidget({
    Key? key,
    required this.diseaseType,
    required this.subTypes,
    required this.selectedDiseases,
    required this.onSelectionChanged,
    required this.hasEditPermission,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DentalColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '$diseaseType 详细类型:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DentalColors.primary,
              ),
            ),
          ),
          ...subTypes.map((subType) {
            final fullType = '$diseaseType - $subType';
            final isSelected = selectedDiseases.contains(fullType);

            return FilterChip(
              label: Text(subType),
              selected: isSelected,
              onSelected: hasEditPermission
                  ? (selected) {
                      final newSelected = Set<String>.from(selectedDiseases);
                      if (selected) {
                        newSelected.add(fullType);
                      } else {
                        newSelected.remove(fullType);
                      }
                      onSelectionChanged(newSelected);
                    }
                  : null,
              backgroundColor: hasEditPermission
                  ? DentalColors.surface
                  : Colors.grey.shade200,
              selectedColor: DentalColors.primary.withValues(alpha: 0.3),
              checkmarkColor: DentalColors.primary,
              labelStyle: TextStyle(
                color:
                    isSelected ? DentalColors.primary : DentalColors.onSurface,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }),
        ],
      ),
    );
  }
}
