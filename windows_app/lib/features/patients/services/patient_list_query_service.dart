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

  static Future<PatientListPageResult> loadAdvancedSearch({
    required PatientProvider patientProvider,
    required Map<String, String>? advancedCriteria,
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

    return PatientListPageResult(
      patients: patients,
      totalCount: patients.length,
    );
  }
}
