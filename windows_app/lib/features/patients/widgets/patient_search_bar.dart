import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onSelectDateRange;
  final VoidCallback onClearFilters;

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
    required this.startDate,
    required this.endDate,
    required this.onSelectDateRange,
    required this.onClearFilters,
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
          border: Border.all(color: context.tokens.shadow),
          boxShadow: [
            BoxShadow(
              color: context.tokens.shadow,
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
                    side: BorderSide(color: context.tokens.shadow),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: showAdvancedSearch
                          ? context.tokens.warning
                          : context.tokens.info,
                    ),
                    tooltip: showAdvancedSearch ? '收起筛选' : '高级筛选',
                    onPressed: onAdvancedSearchToggled,
                  ),
                ),
                const SizedBox(width: 12),
                _DateRangeSelector(
                  startDate: startDate,
                  endDate: endDate,
                  onTap: onSelectDateRange,
                  onClear: onClearFilters,
                ),
                const SizedBox(width: 12),
                Material(
                  color: context.tokens.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.tokens.shadow),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: context.tokens.success,
                    ),
                    tooltip: '添加患者',
                    onPressed: onAddPatient,
                  ),
                ),
              ],
            ),
            if (showAdvancedSearch && advancedFields != null) advancedFields,
          ],
        ),
      ),
    );
  }
}

class _DateRangeSelector extends StatelessWidget {
  const _DateRangeSelector({
    required this.startDate,
    required this.endDate,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: context.tokens.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: context.tokens.border.withValues(alpha: 0.12),
          ),
        ),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: context.tokens.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  startDate == null && endDate == null
                      ? '全部时间'
                      : '${DateFormat('yyyy-MM-dd').format(startDate!)} - ${DateFormat('yyyy-MM-dd').format(endDate!)}',
                  style: TextStyle(
                    color: context.colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (startDate != null && endDate != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
