import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../widgets/dental_icons.dart';
import '../../../widgets/unified_search_field.dart';

class AppointmentFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final DateTime selectedDate;
  final DateTime? endDate;
  final bool isFiltering;
  final bool isDateRangeFiltering;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectDateRange;
  final VoidCallback onToggleFiltering;
  final VoidCallback onSearchClear;

  const AppointmentFilterBar({
    Key? key,
    required this.searchController,
    required this.selectedDate,
    this.endDate,
    required this.isFiltering,
    required this.isDateRangeFiltering,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSelectDateRange,
    required this.onToggleFiltering,
    required this.onSearchClear,
  }) : super(key: key);

  String _buildDateText() {
    if (!isFiltering) {
      return '全部时间';
    }

    final end = endDate;
    if (isDateRangeFiltering && end != null) {
      return '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
          ' - '
          '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    }

    return '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: UnifiedSearchField(
              controller: searchController,
              hintText: '搜索预约记录',
              prefixIcon: Icons.search_rounded,
              searchQuery: searchQuery,
              onChanged: onSearchChanged,
              onClear: onSearchClear,
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              height: 44,
              child: Material(
                color: context.tokens.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onSelectDateRange,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: DentalColors.info,
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 200,
                            maxWidth: 280,
                          ),
                          child: Text(
                            _buildDateText(),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFiltering) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            onPressed: onToggleFiltering,
                            tooltip: '清空日期筛选',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
