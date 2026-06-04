import 'package:flutter/material.dart';

import '../../../widgets/mysql_connection_warning.dart';
import 'patient_empty_state.dart';
import 'patient_filter_bar.dart';
import 'patient_pagination.dart';
import 'patient_search_bar.dart';

class PatientScreenBody extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final bool showAdvancedSearch;
  final Widget? advancedSearchFields;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onAdvancedSearchToggled;
  final VoidCallback onAddPatient;
  final bool searchReadOnly;
  final String sortField;
  final bool sortAscending;
  final int totalPatients;
  final bool showDateFilter;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onDateFilterToggled;
  final String dateFilterType;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<String> onFilterTypeChanged;
  final VoidCallback onSelectDateRange;
  final VoidCallback onClearFilters;
  final bool isLoading;
  final bool hasPatients;
  final Widget patientsList;
  final int totalPages;
  final int currentPage;
  final int patientsPerPage;
  final ValueChanged<int> onPageChanged;

  const PatientScreenBody({
    Key? key,
    required this.searchController,
    required this.searchQuery,
    required this.showAdvancedSearch,
    required this.advancedSearchFields,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onAdvancedSearchToggled,
    required this.onAddPatient,
    required this.searchReadOnly,
    required this.sortField,
    required this.sortAscending,
    required this.totalPatients,
    required this.showDateFilter,
    required this.onSortChanged,
    required this.onDateFilterToggled,
    required this.dateFilterType,
    required this.startDate,
    required this.endDate,
    required this.onFilterTypeChanged,
    required this.onSelectDateRange,
    required this.onClearFilters,
    required this.isLoading,
    required this.hasPatients,
    required this.patientsList,
    required this.totalPages,
    required this.currentPage,
    required this.patientsPerPage,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MySQLConnectionWarning(moduleName: '患者管理'),
        PatientSearchBar(
          searchController: searchController,
          searchQuery: searchQuery,
          showAdvancedSearch: showAdvancedSearch,
          advancedSearchFields: advancedSearchFields,
          onSearchChanged: onSearchChanged,
          onSearchCleared: onSearchCleared,
          onAdvancedSearchToggled: onAdvancedSearchToggled,
          onAddPatient: onAddPatient,
          searchReadOnly: searchReadOnly,
        ),
        PatientFilterBar(
          searchQuery: searchQuery,
          sortField: sortField,
          sortAscending: sortAscending,
          totalPatients: totalPatients,
          showDateFilter: showDateFilter,
          onSortChanged: onSortChanged,
          onDateFilterToggled: onDateFilterToggled,
        ),
        if (showDateFilter)
          PatientDateFilterChip(
            searchQuery: searchQuery,
            dateFilterType: dateFilterType,
            startDate: startDate,
            endDate: endDate,
            onFilterTypeChanged: onFilterTypeChanged,
            onSelectDateRange: onSelectDateRange,
            onClearFilters: onClearFilters,
          ),
        Expanded(
          child: Stack(
            children: [
              if (!hasPatients)
                Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : PatientEmptyState(
                          hasSearchQuery: searchQuery.isNotEmpty,
                          onAddPatient: onAddPatient,
                        ),
                )
              else
                Column(
                  children: [
                    Expanded(child: patientsList),
                    PatientPagination(
                      totalPages: totalPages,
                      currentPage: currentPage,
                      patientsPerPage: patientsPerPage,
                      totalPatients: totalPatients,
                      searchQuery: searchQuery,
                      hasDateFilter: startDate != null,
                      onPageChanged: onPageChanged,
                    ),
                  ],
                ),
              if (isLoading && hasPatients)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white.withOpacity(0.45),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
