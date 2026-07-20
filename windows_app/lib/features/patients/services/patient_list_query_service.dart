import '../../../models/patient.dart';
import '../../../providers/patient_provider.dart';

class PatientListPageResult {
  const PatientListPageResult({
    required this.patients,
    required this.totalCount,
  });

  final List<Patient> patients;
  final int totalCount;
}

class PatientListQueryService {
  const PatientListQueryService._();

  static const int exportBatchSize = 500;

  static Future<PatientListPageResult> loadPage({
    required PatientProvider patientProvider,
    required int page,
    required int pageSize,
    required String searchQuery,
    required String sortField,
    required bool sortAscending,
    required DateTime? startDate,
    required DateTime? endDate,
    required String dateFilterType,
  }) async {
    final patientsData = await patientProvider.getPatientsPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      sortField: sortField,
      sortAscending: sortAscending,
      startDate: startDate,
      endDate: endDate,
      dateFilterType: dateFilterType,
    );

    return PatientListPageResult(
      patients: patientsData['patients'] as List<Patient>,
      totalCount: patientsData['totalCount'] as int,
    );
  }

  static Future<List<Patient>> loadAllPages({
    required PatientProvider patientProvider,
    required String searchQuery,
    required String sortField,
    required bool sortAscending,
    required DateTime? startDate,
    required DateTime? endDate,
    required String dateFilterType,
  }) async {
    final patients = <Patient>[];
    var page = 1;

    while (true) {
      final result = await loadPage(
        patientProvider: patientProvider,
        page: page,
        pageSize: exportBatchSize,
        searchQuery: searchQuery,
        sortField: sortField,
        sortAscending: sortAscending,
        startDate: startDate,
        endDate: endDate,
        dateFilterType: dateFilterType,
      );
      patients.addAll(result.patients);

      if (patients.length >= result.totalCount ||
          result.patients.length < exportBatchSize) {
        return patients;
      }
      page++;
    }
  }

  static Future<PatientListPageResult> loadAdvancedSearch({
    required PatientProvider patientProvider,
    required Map<String, String>? advancedCriteria,
    required int page,
    required int pageSize,
    required String sortField,
    required bool sortAscending,
    required DateTime? startDate,
    required DateTime? endDate,
    required String dateFilterType,
  }) async {
    final patients = await patientProvider.searchPatients(
      '',
      advancedCriteria: advancedCriteria,
      sortField: sortField,
      sortAscending: sortAscending,
      startDate: startDate,
      endDate: endDate,
      dateFilterType: dateFilterType,
    );
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final pagePatients = start >= patients.length
        ? <Patient>[]
        : patients.sublist(
            start, end > patients.length ? patients.length : end);

    return PatientListPageResult(
      patients: pagePatients,
      totalCount: patients.length,
    );
  }
}
