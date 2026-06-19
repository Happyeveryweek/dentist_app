import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';
import 'medical_record_form_input_field.dart';

/// 牙科疾病选择组件
class DentalDiseaseSelectionWidget extends StatelessWidget {
  final Map<String, List<String>> dentalDiseaseOptions;
  final Set<String> selectedDentalDiseases;
  final TextEditingController customController;
  final bool templatesLoaded;
  final bool hasEditPermission;
  final Function(Set<String>) onSelectionChanged;
  final Widget Function({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines,
    bool enabled,
    String? Function(String?)? validator,
  }) buildInputField;

  const DentalDiseaseSelectionWidget({
    Key? key,
    required this.dentalDiseaseOptions,
    required this.selectedDentalDiseases,
    required this.customController,
    required this.templatesLoaded,
    required this.hasEditPermission,
    required this.onSelectionChanged,
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
              Icons.medical_services_rounded,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '当前牙科疾病',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
              templatesLoaded
                  ? Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      children: dentalDiseaseOptions.keys.map((diseaseType) {
                        final isSelected = selectedDentalDiseases.any((selected) => 
                            selected.startsWith(diseaseType));
                        
                        return FilterChip(
                          label: Text(diseaseType),
                          selected: isSelected,
                          onSelected: hasEditPermission ? (selected) {
                            final newSelected = Set<String>.from(selectedDentalDiseases);
                            if (selected) {
                              newSelected.add(diseaseType);
                            } else {
                              newSelected.removeWhere((item) => item.startsWith(diseaseType));
                            }
                            onSelectionChanged(newSelected);
                          } : null,
                          backgroundColor: hasEditPermission ? DentalColors.surface : Colors.grey.shade200,
                          selectedColor: DentalColors.primary.withOpacity(0.2),
                          checkmarkColor: DentalColors.primary,
                          labelStyle: TextStyle(
                            color: hasEditPermission ? 
                              (isSelected ? DentalColors.primary : DentalColors.onSurface) : 
                              Colors.grey,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    )
                  : const CircularProgressIndicator(),

              // 显示选中疾病类型的子类型
              if (templatesLoaded)
                ...dentalDiseaseOptions.entries.where((entry) => 
                    selectedDentalDiseases.any((selected) => selected.startsWith(entry.key))
                ).map((entry) => DentalDiseaseSubTypeSelectionWidget(
                  diseaseType: entry.key,
                  subTypes: entry.value,
                  selectedDentalDiseases: selectedDentalDiseases,
                  hasEditPermission: hasEditPermission,
                  onSelectionChanged: onSelectionChanged,
                )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 其他牙科疾病输入框
        buildInputField(
          controller: customController,
          label: '其他牙科疾病',
          hint: '请输入其他牙科疾病情况',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
          enabled: hasEditPermission,
        ),
      ],
    );
  }
}

/// 牙科疾病子类型选择组件
class DentalDiseaseSubTypeSelectionWidget extends StatelessWidget {
  final String diseaseType;
  final List<String> subTypes;
  final Set<String> selectedDentalDiseases;
  final bool hasEditPermission;
  final Function(Set<String>) onSelectionChanged;

  const DentalDiseaseSubTypeSelectionWidget({
    Key? key,
    required this.diseaseType,
    required this.subTypes,
    required this.selectedDentalDiseases,
    required this.hasEditPermission,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DentalColors.primary.withOpacity(0.2),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DentalColors.primary,
              ),
            ),
          ),
          ...subTypes.map((subType) {
            final fullType = '$diseaseType - $subType';
            final isSelected = selectedDentalDiseases.contains(fullType);
            
            return FilterChip(
              label: Text(subType),
              selected: isSelected,
              onSelected: hasEditPermission ? (selected) {
                final newSelected = Set<String>.from(selectedDentalDiseases);
                if (selected) {
                  newSelected.add(fullType);
                } else {
                  newSelected.remove(fullType);
                }
                onSelectionChanged(newSelected);
              } : null,
              backgroundColor: hasEditPermission ? DentalColors.surface : Colors.grey.shade200,
              selectedColor: DentalColors.primary.withOpacity(0.3),
              checkmarkColor: DentalColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? DentalColors.primary : DentalColors.onSurface,
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
