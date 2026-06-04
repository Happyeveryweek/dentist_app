import '../../../models/patient.dart';
import '../../../providers/patient_provider.dart';
import 'patient_list_query_service.dart';

class PatientListStateResult {
  const PatientListStateResult({
    required this.patients,
    required this.totalPatients,
    required this.isLoading,
    required this.isSearching,
    required this.hasSearchResults,
    required this.searchQuery,
  });

  final List<Patient> patients;
  final int totalPatients;
  final bool isLoading;
  final bool isSearching;
  final bool hasSearchResults;
  final String searchQuery;
}

/// 排序状态切换结果
class PatientSortChangeResult {
  const PatientSortChangeResult({
    required this.sortField,
    required this.sortAscending,
  });

  final String sortField;
  final bool sortAscending;
}

/// 分页计算结果
class PatientPaginationResult {
  const PatientPaginationResult({
    required this.totalPages,
    required this.displayTotalPages,
  });

  final int totalPages;
  final int displayTotalPages;
}

class PatientListStateService {
  const PatientListStateService._();

  static PatientListStateResult fromPageResult({
    required PatientListPageResult result,
    required String searchQuery,
    required bool isSearching,
  }) {
    return PatientListStateResult(
      patients: result.patients,
      totalPatients: result.totalCount,
      isLoading: false,
      isSearching: isSearching,
      hasSearchResults: searchQuery.isNotEmpty,
      searchQuery: searchQuery,
    );
  }

  static PatientListStateResult fromAdvancedSearchResult({
    required PatientListPageResult result,
    required String searchQuery,
  }) {
    return PatientListStateResult(
      patients: result.patients,
      totalPatients: result.totalCount,
      isLoading: false,
      isSearching: false,
      hasSearchResults: true,
      searchQuery: searchQuery,
    );
  }

  /// 计算点击排序后的新排序状态
  static PatientSortChangeResult computeSortChange({
    required String currentField,
    required String clickedField,
    required bool currentAscending,
  }) {
    if (currentField == clickedField) {
      return PatientSortChangeResult(
        sortField: currentField,
        sortAscending: !currentAscending,
      );
    }
    return PatientSortChangeResult(
      sortField: clickedField,
      sortAscending: false,
    );
  }

  /// 根据总记录数和每页条数计算分页信息
  static PatientPaginationResult computePagination({
    required int totalPatients,
    required int patientsPerPage,
  }) {
    final totalPages = (totalPatients / patientsPerPage).ceil();
    final displayTotalPages = totalPages > 0 ? totalPages : 1;
    return PatientPaginationResult(
      totalPages: totalPages,
      displayTotalPages: displayTotalPages,
    );
  }

  /// 从数据库获取最新患者信息（用于编辑前刷新数据）
  static Future<Patient> fetchFreshPatient({
    required PatientProvider patientProvider,
    required Patient patient,
  }) async {
    if (patient.id == null) return patient;

    try {
      final freshPatient = await patientProvider.getPatient(patient.id!);
      if (freshPatient == null) {
        return patient;
      }
      return freshPatient;
    } catch (e) {
      return patient;
    }
  }
}
