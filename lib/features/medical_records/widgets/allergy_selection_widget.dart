import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';
import 'medical_record_form_input_field.dart';

/// 过敏史选择组件
class AllergySelectionWidget extends StatelessWidget {
  final Map<String, List<String>> allergyOptions;
  final Set<String> selectedAllergies;
  final TextEditingController customController;
  final bool templatesLoaded;
  final bool hasEditPermission;
  final Function(Set<String>) onAllergyChanged;
  final Widget Function({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines,
    bool enabled,
    String? Function(String?)? validator,
  }) buildInputField;

  const AllergySelectionWidget({
    Key? key,
    required this.allergyOptions,
    required this.selectedAllergies,
    required this.customController,
    required this.templatesLoaded,
    required this.hasEditPermission,
    required this.onAllergyChanged,
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
              Icons.warning_rounded,
              size: 18,
              color: DentalColors.error,
            ),
            const SizedBox(width: 8),
            Text(
              '过敏史',
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
            color: DentalColors.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: DentalColors.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 过敏类型选择
              templatesLoaded
                  ? Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      children: allergyOptions.keys.map((allergyType) {
                        final isSelected = selectedAllergies.any((selected) => 
                            selected.startsWith(allergyType));
                        
                        return FilterChip(
                          label: Text(allergyType),
                          selected: isSelected,
                          onSelected: hasEditPermission ? (selected) {
                            final newSelected = Set<String>.from(selectedAllergies);
                            if (selected) {
                              newSelected.add(allergyType);
                            } else {
                              newSelected.removeWhere((item) => item.startsWith(allergyType));
                            }
                            onAllergyChanged(newSelected);
                          } : null,
                          backgroundColor: hasEditPermission ? DentalColors.surface : Colors.grey.shade200,
                          selectedColor: DentalColors.error.withOpacity(0.2),
                          checkmarkColor: DentalColors.error,
                          labelStyle: TextStyle(
                            color: hasEditPermission ? 
                              (isSelected ? DentalColors.error : DentalColors.onSurface) : 
                              Colors.grey,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    )
                  : const CircularProgressIndicator(),

              // 显示选中过敏类型的具体项目
              if (templatesLoaded)
                ...allergyOptions.entries.where((entry) => 
                    selectedAllergies.any((selected) => selected.startsWith(entry.key))
                ).map((entry) => AllergySubTypeSelectionWidget(
                  allergyType: entry.key,
                  items: entry.value,
                  selectedAllergies: selectedAllergies,
                  hasEditPermission: hasEditPermission,
                  onAllergyChanged: onAllergyChanged,
                )),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 其他过敏输入框
        buildInputField(
          controller: customController,
          label: '其他过敏',
          hint: '请输入其他过敏情况',
          icon: Icons.edit_note_rounded,
          maxLines: 2,
          enabled: hasEditPermission,
        ),
      ],
    );
  }
}

/// 过敏子类型选择组件
class AllergySubTypeSelectionWidget extends StatelessWidget {
  final String allergyType;
  final List<String> items;
  final Set<String> selectedAllergies;
  final bool hasEditPermission;
  final Function(Set<String>) onAllergyChanged;

  const AllergySubTypeSelectionWidget({
    Key? key,
    required this.allergyType,
    required this.items,
    required this.selectedAllergies,
    required this.hasEditPermission,
    required this.onAllergyChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DentalColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DentalColors.error.withOpacity(0.3),
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
              '$allergyType 具体项目:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DentalColors.error,
              ),
            ),
          ),
          ...items.map((item) {
            final fullType = '$allergyType - $item';
            final isSelected = selectedAllergies.contains(fullType);
            
            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: hasEditPermission ? (selected) {
                final newSelected = Set<String>.from(selectedAllergies);
                if (selected) {
                  newSelected.add(fullType);
                } else {
                  newSelected.remove(fullType);
                }
                onAllergyChanged(newSelected);
              } : null,
              backgroundColor: hasEditPermission ? DentalColors.surface : Colors.grey.shade200,
              selectedColor: DentalColors.error.withOpacity(0.3),
              checkmarkColor: DentalColors.error,
              labelStyle: TextStyle(
                color: hasEditPermission ? 
                  (isSelected ? DentalColors.error : DentalColors.onSurface) : 
                  Colors.grey,
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
