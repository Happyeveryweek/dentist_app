import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../widgets/dental_icons.dart';
import '../../../widgets/unified_search_field.dart';

class PatientSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool showAdvancedSearch;
  final Widget? advancedSearchFields;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onAdvancedSearchToggled;
  final VoidCallback onAddPatient;
  final bool searchReadOnly;

  const PatientSearchBar({
    Key? key,
    required this.searchController,
    required this.searchQuery,
    required this.showAdvancedSearch,
    required this.advancedSearchFields,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onAdvancedSearchToggled,
    required this.onAddPatient,
    this.searchReadOnly = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final advancedFields = advancedSearchFields;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: UnifiedSearchField(
                    controller: searchController,
                    hintText: '快速搜索患者姓名、拼音、电话、地址等',
                    prefixIcon: DentalIcons.hospitalUser,
                    searchQuery: searchQuery,
                    readOnly: searchReadOnly,
                    onChanged: onSearchChanged,
                    onClear: onSearchCleared,
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: context.tokens.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side:
                        BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: showAdvancedSearch
                          ? DentalColors.warning
                          : DentalColors.info,
                    ),
                    tooltip: showAdvancedSearch ? '收起筛选' : '高级筛选',
                    onPressed: onAdvancedSearchToggled,
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: context.tokens.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side:
                        BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.green,
                    ),
                    tooltip: '添加患者',
                    onPressed: onAddPatient,
                  ),
                ),
              ],
            ),
            if (showAdvancedSearch && advancedFields != null)
              advancedFields,
          ],
        ),
      ),
    );
  }
}
