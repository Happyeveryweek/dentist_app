import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../widgets/unified_search_field.dart';

/// 财务管理搜索栏组件（搜索框 + 排序 + 日期范围 + 高级筛选）
class FinancialSearchBar extends StatelessWidget {
  const FinancialSearchBar({
    super.key,
    required this.displayMode,
    required this.searchController,
    required this.searchQuery,
    required this.sortBy,
    required this.sortAscending,
    required this.startDate,
    required this.endDate,
    required this.hasAdvancedFilter,
    required this.searchReadOnly,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onSortChanged,
    required this.onDateRangeTap,
    required this.onDateRangeCleared,
    required this.onAdvancedFilterTap,
  });

  final String displayMode;
  final TextEditingController searchController;
  final String searchQuery;
  final String sortBy;
  final bool sortAscending;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasAdvancedFilter;
  final bool searchReadOnly;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onDateRangeTap;
  final VoidCallback onDateRangeCleared;
  final VoidCallback onAdvancedFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: context.tokens.shadow.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: context.tokens.shadow.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // 搜索框
            Expanded(
              child: UnifiedSearchField(
                controller: searchController,
                labelText: displayMode == 'patient' ? '搜索患者' : '搜索收费记录',
                hintText: displayMode == 'patient' ? '搜索姓名、病历号' : '搜索姓名、病历号',
                prefixIcon: Icons.search_rounded,
                searchQuery: searchQuery,
                readOnly: searchReadOnly,
                onChanged: onSearchChanged,
                onClear: onSearchCleared,
              ),
            ),
            const SizedBox(width: 12),
            // 排序切换
            PopupMenuButton<String>(
              icon: Icon(Icons.sort_rounded, color: context.colors.onSurface),
              onSelected: onSortChanged,
              itemBuilder: (BuildContext context) =>
                  _buildSortMenuItems(context),
            ),
            const SizedBox(width: 12),
            // 时间范围选择
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                height: 44,
                child: Material(
                  color: context.tokens.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: context.tokens.border.withValues(alpha: 0.12)),
                  ),
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(16),
                    onTap: onDateRangeTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: context.tokens.textMuted),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                                minWidth: 120, maxWidth: 280),
                            child: Text(
                              (startDate == null && endDate == null)
                                  ? '全部时间'
                                  : '${DateFormat('yyyy-MM-dd').format(startDate ?? DateTime.now())} - ${DateFormat('yyyy-MM-dd').format(endDate ?? DateTime.now())}',
                              style: TextStyle(
                                  color: context.colors.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (startDate != null || endDate != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: onDateRangeCleared,
                              borderRadius: BorderRadius.circular(12),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: context.tokens.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 高级筛选按钮（仅记录模式）
            if (displayMode == 'record')
              SizedBox(
                height: 44,
                width: 44,
                child: Material(
                  color: context.tokens.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: context.tokens.border.withValues(alpha: 0.12)),
                  ),
                  elevation: 0.5,
                  child: IconButton(
                    icon: Icon(Icons.tune,
                        color: hasAdvancedFilter
                            ? context.tokens.primaryAccent
                            : context.colors.onSurfaceVariant),
                    tooltip: '高级筛选',
                    onPressed: onAdvancedFilterTap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildSortMenuItems(BuildContext context) {
    if (displayMode == 'patient') {
      return _patientSortItems(context);
    } else {
      return _recordSortItems(context);
    }
  }

  List<PopupMenuEntry<String>> _patientSortItems(BuildContext context) {
    return <PopupMenuEntry<String>>[
      _sortMenuItem(context, 'updated_at', Icons.update, '按最近更新'),
      _sortMenuItem(context, 'charge_date', Icons.calendar_today, '按收费日期'),
      const PopupMenuDivider(),
      _sortMenuItem(context, 'receivable', Icons.request_quote, '按应收费'),
      _sortMenuItem(context, 'received', Icons.payments, '按已收费'),
      _sortMenuItem(context, 'debt', Icons.pending, '按欠费'),
    ];
  }

  List<PopupMenuEntry<String>> _recordSortItems(BuildContext context) {
    return <PopupMenuEntry<String>>[
      _sortMenuItem(context, 'updated_at', Icons.update, '按最近更新'),
      _sortMenuItem(context, 'charge_date', Icons.calendar_today, '按收费日期'),
      const PopupMenuDivider(),
      _sortMenuItem(context, 'receivable', Icons.request_quote, '按应收费'),
      _sortMenuItem(context, 'received', Icons.payments, '按已收费'),
      _sortMenuItem(context, 'processing_fee', Icons.build, '按加工费'),
    ];
  }

  PopupMenuItem<String> _sortMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) {
    final isActive = sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isActive ? Theme.of(context).primaryColor : null),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (isActive)
            Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
        ],
      ),
    );
  }
}
