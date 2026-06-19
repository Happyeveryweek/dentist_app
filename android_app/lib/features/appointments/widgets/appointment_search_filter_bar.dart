import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dentist_app/theme/app_theme.dart';

class AppointmentSearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final Function(String) onSearchSubmitted;
  final Function() onClearSearch;
  final Function() onFilterPressed;

  const AppointmentSearchFilterBar({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索患者姓名或治疗项目',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.secondaryText,
                ),
                suffixIcon:
                    searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.secondaryText,
                          ),
                          onPressed: onClearSearch,
                        )
                        : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
              ),
              style: const TextStyle(color: AppTheme.primaryText, fontSize: 14),
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list_alt,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '筛选',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 14),
                ),
              ],
            ),
            onPressed: onFilterPressed,
          ),
        ],
      ),
    );
  }
}
