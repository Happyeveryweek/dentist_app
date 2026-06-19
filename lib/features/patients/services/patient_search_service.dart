import '../../../models/patient.dart';
import '../../../data_sources/patient_data_source.dart';
import '../../../utils/pinyin_util.dart';

/// 患者搜索与索引服务
/// 负责处理搜索业务逻辑，SQL 操作委托给 Data Source
class PatientSearchService {
  final PatientDataSource? Function() getCurrentDataSource;

  PatientSearchService({
    required this.getCurrentDataSource,
  });

  /// 搜索患者 ID（姓名/拼音/首字母/病历号）
  Future<List<int>> searchPatientIds(String query) async {
    if (query.trim().isEmpty) return [];
    final ds = getCurrentDataSource();
    if (ds == null) return [];
    return await ds.searchPatientIds(query);
  }

  /// 综合搜索患者（支持分页、排序、日期过滤和高级条件）
  Future<List<Patient>> searchPatients(
    String query, {
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
    Map<String, String>? advancedCriteria,
  }) async {
    final ds = getCurrentDataSource();
    if (ds == null) return [];

    final hasAdvancedCriteria =
        advancedCriteria != null && advancedCriteria.isNotEmpty;
    final normalizedQuery = query.trim();

    final patients = await ds.searchPatients(
      hasAdvancedCriteria && normalizedQuery.isEmpty ? '' : normalizedQuery,
    );

    final filtered = patients.where((patient) {
      if (normalizedQuery.isNotEmpty && !_matchesText(patient, normalizedQuery)) {
        return false;
      }

      if (hasAdvancedCriteria && !_matchesAdvancedCriteria(patient, advancedCriteria)) {
        return false;
      }

      if (startDate != null && endDate != null) {
        final targetDate = _getDateForFilter(patient, dateFilterType);
        if (targetDate == null ||
            targetDate.isBefore(_dateOnly(startDate)) ||
            targetDate.isAfter(_dateOnly(endDate))) {
          return false;
        }
      }

      return true;
    }).toList();

    _sortPatients(
      filtered,
      sortField: sortField,
      sortAscending: sortAscending,
    );

    return filtered;
  }

  /// 批量更新所有患者的拼音索引（维护任务）
  Future<void> updateAllPatientsPinyin() async {
    final ds = getCurrentDataSource();
    if (ds == null) return;
    await ds.updateAllPatientsPinyin();
  }

  bool _matchesAdvancedCriteria(
    Patient patient,
    Map<String, String> advancedCriteria,
  ) {
    for (final entry in advancedCriteria.entries) {
      final keyword = entry.value.trim();
      if (keyword.isEmpty) continue;

      switch (entry.key) {
        case 'name':
          if (!_matchesName(patient, keyword)) return false;
          break;
        case 'address':
          if (!_matchesAddress(patient, keyword)) return false;
          break;
        case 'phone':
          if (!_matchesPhone(patient, keyword)) return false;
          break;
        case 'medical_record':
          if (!_matchesMedicalRecord(patient, keyword)) return false;
          break;
      }
    }

    return true;
  }

  bool _matchesText(Patient patient, String query) {
    return _matchesName(patient, query) ||
        _matchesAddress(patient, query) ||
        _matchesPhone(patient, query) ||
        _matchesMedicalRecord(patient, query) ||
        _matchesIdentificationNumber(patient, query);
  }

  bool _matchesName(Patient patient, String query) {
    return _contains(patient.name, query) ||
        _contains(patient.name_pinyin, query) ||
        _contains(PinyinUtil.toPinyin(patient.name), query) ||
        _contains(PinyinUtil.toPinyin(patient.name).replaceAll(' ', ''), query) ||
        _contains(patient.name_initials, query) ||
        _contains(PinyinUtil.getInitials(patient.name), query) ||
        _contains(PinyinUtil.getFirstLetters(patient.name), query);
  }

  bool _matchesAddress(Patient patient, String query) {
    return _contains(patient.address, query) ||
        _contains(patient.address_pinyin, query);
  }

  bool _matchesPhone(Patient patient, String query) {
    final normalizedQuery = query.replaceAll(' ', '');
    return patient.phoneList.any(
      (phone) => _contains(phone, normalizedQuery),
    );
  }

  bool _matchesMedicalRecord(Patient patient, String query) {
    return _contains(patient.medical_record_number?.toString(), query);
  }

  bool _matchesIdentificationNumber(Patient patient, String query) {
    return _contains(patient.identification_number, query);
  }

  bool _contains(String? source, String query) {
    if (source == null || query.isEmpty) return false;
    final normalizedSource = source.toLowerCase().replaceAll(' ', '');
    final normalizedQuery = query.toLowerCase().replaceAll(' ', '');
    return normalizedSource.contains(normalizedQuery);
  }

  DateTime? _getDateForFilter(Patient patient, String dateFilterType) {
    switch (dateFilterType) {
      case 'updated_at':
        return _dateOnly(patient.updated_at);
      case 'first_visit_date':
      default:
        return _dateOnly(patient.first_visit_date);
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _sortPatients(
    List<Patient> patients, {
    String? sortField,
    required bool sortAscending,
  }) {
    if (sortField == null || sortField.isEmpty) return;

    int comparePatient(Patient a, Patient b) {
      int result;
      switch (sortField) {
        case 'name':
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'age':
          result = a.age.compareTo(b.age);
          break;
        case 'medical_record_number':
          result = _compareNullableInt(
            a.medical_record_number,
            b.medical_record_number,
          );
          break;
        case 'first_visit_date':
          result = a.first_visit_date.compareTo(b.first_visit_date);
          break;
        case 'updated_at':
          result = a.updated_at.compareTo(b.updated_at);
          break;
        default:
          result = a.updated_at.compareTo(b.updated_at);
      }
      return sortAscending ? result : -result;
    }

    patients.sort(comparePatient);
  }

  int _compareNullableInt(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}
