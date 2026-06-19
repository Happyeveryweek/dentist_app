import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';

/// 患者搜索筛选栏组件
/// 职责：显示搜索框和时间筛选功能
class PatientSearchFilterBar extends StatefulWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onSearch;
  final Function() onClearSearch;
  final bool showTimeFilter;
  final String dateFilterType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isDateRangeFiltering;
  final Function(bool) onToggleTimeFilter;
  final Function(String) onDateFilterTypeChange;
  final Function(DateTime?) onStartDateChange;
  final Function(DateTime?) onEndDateChange;
  final Function() onApplyTimeFilter;
  final Function() onClearTimeFilter;

  const PatientSearchFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearch,
    required this.onClearSearch,
    required this.showTimeFilter,
    required this.dateFilterType,
    this.startDate,
    this.endDate,
    required this.isDateRangeFiltering,
    required this.onToggleTimeFilter,
    required this.onDateFilterTypeChange,
    required this.onStartDateChange,
    required this.onEndDateChange,
    required this.onApplyTimeFilter,
    required this.onClearTimeFilter,
  });

  @override
  State<PatientSearchFilterBar> createState() => _PatientSearchFilterBarState();
}

class _PatientSearchFilterBarState extends State<PatientSearchFilterBar> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      widget.onSearch(value.trim());
    });
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    widget.onSearch(value.trim());
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    widget.onClearSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.padding),
      color: AppTheme.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索姓名、拼音、电话、病历号或地址',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.secondaryText,
                    ),
                    suffixIcon:
                        widget.searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppTheme.secondaryText,
                              ),
                              onPressed: _clearSearch,
                            )
                            : null,
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.smallBorderRadius,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _scheduleSearch(value);
                  },
                  onSubmitted: (value) {
                    _submitSearch(value);
                  },
                ),
              ),
            ],
          ),
          if (widget.searchQuery.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '提示: 可通过姓名、拼音、地址、电话等进行精确或模糊搜索',
                style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
            ),
          const SizedBox(height: 16),
          // 时间筛选区域
          _buildTimeFilterSection(),
        ],
      ),
    );
  }

  // 构建时间筛选区域
  Widget _buildTimeFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间筛选标题和切换按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.showTimeFilter ? '隐藏时间筛选' : '时间筛选',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  widget.onToggleTimeFilter(!widget.showTimeFilter);
                },
                icon: Icon(
                  widget.showTimeFilter
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.primaryColor,
                ),
                tooltip: widget.showTimeFilter ? '隐藏时间筛选' : '显示时间筛选',
              ),
            ],
          ),

          // 时间筛选内容
          if (widget.showTimeFilter) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 筛选类型选择
            Row(
              children: [
                const Text(
                  '按: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryText,
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterTypeButton('首诊时间', 'first_visit_date', Icons.event),
                const SizedBox(width: 12),
                _buildFilterTypeButton('更新时间', 'updated_at', Icons.update),
              ],
            ),

            const SizedBox(height: 16),

            // 日期范围选择
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    '开始日期',
                    widget.startDate,
                    (date) => widget.onStartDateChange(date),
                    isStartDate: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    '结束日期',
                    widget.endDate,
                    (date) => widget.onEndDateChange(date),
                    isStartDate: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        widget.startDate != null && widget.endDate != null
                            ? widget.onApplyTimeFilter
                            : null,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('应用筛选'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onClearTimeFilter,
                    icon: const Icon(Icons.clear),
                    label: const Text('清除筛选'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryText,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 当前筛选状态显示
            if (widget.isDateRangeFiltering &&
                widget.startDate != null &&
                widget.endDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前筛选: ${DateFormat('yyyy-MM-dd').format(widget.startDate!)} 至 ${DateFormat('yyyy-MM-dd').format(widget.endDate!)} (${widget.dateFilterType == 'first_visit_date' ? '首诊时间' : '更新时间'})',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // 构建筛选类型按钮
  Widget _buildFilterTypeButton(String label, String value, IconData icon) {
    final isSelected = widget.dateFilterType == value;
    return GestureDetector(
      onTap: () {
        widget.onDateFilterTypeChange(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.secondaryText,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建日期选择字段
  Widget _buildDateField(
    String label,
    DateTime? date,
    Function(DateTime?) onDateSelected, {
    required bool isStartDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? selectedDate = await showDialog<DateTime>(
              context: context,
              builder: (BuildContext context) {
                return ModernDatePickerDialog(
                  initialDate: date ?? DateTime.now(),
                  firstDate:
                      isStartDate
                          ? DateTime(2000)
                          : (widget.startDate ?? DateTime(2000)),
                  lastDate:
                      isStartDate
                          ? (widget.endDate ?? DateTime(2100))
                          : DateTime(2100),
                  title: '选择$label',
                );
              },
            );
            if (selectedDate != null && context.mounted) {
              onDateSelected(selectedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('yyyy年MM月dd日').format(date)
                        : '请选择日期',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          date != null
                              ? AppTheme.primaryText
                              : AppTheme.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
