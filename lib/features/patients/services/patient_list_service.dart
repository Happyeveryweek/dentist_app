import 'dart:async';
import '../../../models/patient.dart';
import '../../../data_sources/patient_data_source.dart';

/// 患者列表查询与加载服务
class PatientListService {
  final PatientDataSource? Function() getCurrentDataSource;

  PatientListService({
    required this.getCurrentDataSource,
  });

  /// 获取所有患者
  Future<List<Patient>> getAllPatients() async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    return await ds.getAllPatients();
  }

  /// 获取患者分页数据
  Future<Map<String, dynamic>> getPatientsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  }) async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    return await ds.getPatientsPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      sortField: sortField,
      sortAscending: sortAscending,
      startDate: startDate,
      endDate: endDate,
      dateFilterType: dateFilterType,
    );
  }

  /// 根据医生姓名获取患者
  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    return await ds.getPatientsByDoctor(doctorName);
  }

  /// 根据 ID 列表批量获取患者
  Future<List<Patient>> getPatientsByIds(List<int> ids) async {
    final ds = getCurrentDataSource();
    if (ds == null) throw Exception('数据源未初始化');
    return await ds.getPatientsByIds(ids);
  }
}
