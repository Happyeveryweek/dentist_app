import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_models.dart';
import 'patient_search_filter_bar.dart';
import 'patient_stats_bar.dart';
import 'patient_empty_state.dart';
import 'patient_list_card.dart';

class PatientsScreenBody extends StatelessWidget {
  final bool isLoading;
  final List<Patient> patients;
  final bool hasMoreData;
  final int totalPatientsInDatabase;
  final int currentPage;
  final String searchQuery;
  final bool showTimeFilter;
  final String dateFilterType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isDateRangeFiltering;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<bool> onToggleTimeFilter;
  final ValueChanged<String> onDateFilterTypeChange;
  final ValueChanged<DateTime?> onStartDateChange;
  final ValueChanged<DateTime?> onEndDateChange;
  final VoidCallback onApplyTimeFilter;
  final VoidCallback onClearTimeFilter;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddPatient;
  final void Function(Patient) onShowPatientDetail;
  final VoidCallback onOpenSortOptions;
  final void Function(Patient) onEditPatient;
  final void Function(Patient) onDeletePatient;

  const PatientsScreenBody({
    super.key,
    required this.isLoading,
    required this.patients,
    required this.hasMoreData,
    required this.totalPatientsInDatabase,
    required this.currentPage,
    required this.searchQuery,
    required this.showTimeFilter,
    required this.dateFilterType,
    required this.startDate,
    required this.endDate,
    required this.isDateRangeFiltering,
    required this.searchController,
    required this.scrollController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onToggleTimeFilter,
    required this.onDateFilterTypeChange,
    required this.onStartDateChange,
    required this.onEndDateChange,
    required this.onApplyTimeFilter,
    required this.onClearTimeFilter,
    required this.onRefresh,
    required this.onAddPatient,
    required this.onShowPatientDetail,
    required this.onOpenSortOptions,
    required this.onEditPatient,
    required this.onDeletePatient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        PatientSearchFilterBar(
          searchController: searchController,
          searchQuery: searchQuery,
          onSearch: onSearch,
          onClearSearch: onClearSearch,
          showTimeFilter: showTimeFilter,
          dateFilterType: dateFilterType,
          startDate: startDate,
          endDate: endDate,
          isDateRangeFiltering: isDateRangeFiltering,
          onToggleTimeFilter: onToggleTimeFilter,
          onDateFilterTypeChange: onDateFilterTypeChange,
          onStartDateChange: onStartDateChange,
          onEndDateChange: onEndDateChange,
          onApplyTimeFilter: onApplyTimeFilter,
          onClearTimeFilter: onClearTimeFilter,
        ),
        PatientStatsBar(
          totalCount: totalPatientsInDatabase,
          currentCount: patients.length,
          currentPage: currentPage,
          hasMoreData: hasMoreData,
          searchQuery: searchQuery,
          isDateRangeFiltering: isDateRangeFiltering,
        ),
        Expanded(
          child:
              isLoading
                  ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          '加载患者数据中...',
                          style: TextStyle(color: AppTheme.secondaryText),
                        ),
                      ],
                    ),
                  )
                  : patients.isEmpty
                  ? PatientEmptyState(
                    searchQuery: searchQuery,
                    onClearSearch: onClearSearch,
                    onAddPatient: onAddPatient,
                  )
                  : RefreshIndicator(
                    onRefresh: onRefresh,
                    color: AppTheme.primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.padding),
                      controller: scrollController,
                      itemCount:
                          patients.length +
                          (hasMoreData && searchQuery.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == patients.length &&
                            hasMoreData &&
                            searchQuery.isEmpty) {
                          return _buildLoadingMoreIndicator();
                        }

                        final patient = patients[index];
                        return PatientListCard(
                          patient: patient,
                          onTap: () => onShowPatientDetail(patient),
                          onEdit: () => onEditPatient(patient),
                          onDelete: () => onDeletePatient(patient),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.teal.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '患者管理',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.teal.shade600),
                onPressed: onOpenSortOptions,
                tooltip: '排序选项',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.teal.shade100),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const Column(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '加载更多患者数据...',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
