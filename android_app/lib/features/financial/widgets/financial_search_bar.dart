import 'package:flutter/material.dart';

/// 财务搜索栏组件
/// 职责：显示财务记录的搜索栏，包括搜索框、排序按钮、时间筛选
class FinancialSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(String) onSearchSubmitted;
  final Function() onClearSearch;
  final Function() onSortPressed;
  final Function() onDateFilterPressed;
  final Function() onClearDateFilter;

  const FinancialSearchBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onSortPressed,
    required this.onDateFilterPressed,
    required this.onClearDateFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索患者姓名、拼音、拼音首字母...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: onClearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    // 只更新 UI，不触发搜索
                  },
                  onSubmitted: onSearchSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => onSearchSubmitted(searchController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('搜索'),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200, width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.sort, color: Colors.purple.shade600, size: 20),
                  onPressed: onSortPressed,
                  tooltip: '排序选项',
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDateFilterPressed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (startDate == null && endDate == null)
                                ? '全部时间'
                                : '${_formatDate(startDate!)} - ${_formatDate(endDate!)}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (startDate != null || endDate != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: onClearDateFilter,
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.black45),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetButton('本月', 'this_month'),
                const SizedBox(width: 8),
                _buildPresetButton('上月', 'last_month'),
                const SizedBox(width: 8),
                _buildPresetButton('30天', '30d'),
                const SizedBox(width: 8),
                _buildPresetButton('今年', 'this_year'),
                const SizedBox(width: 8),
                _buildPresetButton('全部', 'all'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildPresetButton(String label, String preset) {
    final isSelected = _isPresetSelected(preset);
    return GestureDetector(
      onTap: () => onDateFilterPressed(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isPresetSelected(String preset) {
    if (preset == 'all') {
      return startDate == null && endDate == null;
    }

    final now = DateTime.now();
    DateTime? expectedStart;
    DateTime? expectedEnd;

    switch (preset) {
      case 'this_month':
        expectedStart = DateTime(now.year, now.month, 1);
        expectedEnd = DateTime(now.year, now.month + 1, 0);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        expectedStart = DateTime(lastMonth.year, lastMonth.month, 1);
        expectedEnd = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case '30d':
        expectedStart = now.subtract(const Duration(days: 29));
        expectedEnd = now;
        break;
      case 'this_year':
        expectedStart = DateTime(now.year, 1, 1);
        expectedEnd = DateTime(now.year, 12, 31);
        break;
    }

    if (expectedStart == null || expectedEnd == null) return false;

    return startDate != null &&
           endDate != null &&
           _isSameDay(startDate!, expectedStart) &&
           _isSameDay(endDate!, expectedEnd);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}
