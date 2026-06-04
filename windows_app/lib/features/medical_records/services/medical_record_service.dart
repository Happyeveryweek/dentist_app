import '../../../models/patient_medical_record.dart';
import '../../../data_sources/medical_record_data_source.dart';
import 'medical_record_sync_service.dart';
import 'medical_record_permission_service.dart';
import '../helpers/medical_record_cache_helper.dart';

/// 病历记录管理服务
/// 负责处理病历记录的CRUD操作
class MedicalRecordService {
  final MedicalRecordDataSource? Function() getCurrentDataSource;
  final void Function(bool) setLoading;
  final void Function() clearError;
  final void Function(String) setError;
  final void Function() notifyListeners;
  final MedicalRecordSyncService syncService;
  final MedicalRecordPermissionService permissionService;
  final MedicalRecordCacheHelper cacheHelper;

  MedicalRecordService({
    required this.getCurrentDataSource,
    required this.setLoading,
    required this.clearError,
    required this.setError,
    required this.notifyListeners,
    required this.syncService,
    required this.permissionService,
    required this.cacheHelper,
  });

  /// 数据验证
  String? validateMedicalRecord(PatientMedicalRecord record) {
    if (record.patientId <= 0) {
      return '患者ID无效';
    }

    if (record.recordDate.isAfter(DateTime.now().add(Duration(days: 1)))) {
      return '病历日期不能是未来日期';
    }

    if (record.chiefComplaint.trim().isEmpty) {
      return '主诉不能为空';
    }

    if (record.doctorName.trim().isEmpty) {
      return '医生姓名不能为空';
    }

    return null; // 验证通过
  }

  /// 获取患者的所有病历记录
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId, {bool forceRefresh = false}) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 检查缓存
      if (!forceRefresh && cacheHelper.isCacheValid() && cacheHelper.cachedMedicalRecords.containsKey(patientId)) {
        return cacheHelper.cachedMedicalRecords[patientId]!;
      }

      // 从数据源获取数据
      final records = await dataSource.getPatientMedicalRecords(patientId);
      // 更新缓存
      cacheHelper.updateCache(patientId, records);

      clearError();
      return records;
    } catch (e) {
      print('获取患者病历记录时出错: $e');
      setError('获取病历记录失败: $e');

      // 优雅降级：如果有缓存数据，返回缓存
      if (cacheHelper.cachedMedicalRecords.containsKey(patientId)) {
        print('MedicalRecordService: 连接失败，返回缓存数据');
        return cacheHelper.cachedMedicalRecords[patientId]!;
      }

      return [];
    } finally {
      setLoading(false);
    }
  }

  /// 根据ID获取病历记录
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      print('MedicalRecordService: 获取病历记录，ID: $id');

      final record = await dataSource.getMedicalRecordById(id);
      print('MedicalRecordService: ${record != null ? '找到病历记录' : '未找到病历记录'}');

      clearError();
      return record;
    } catch (e) {
      print('根据ID获取病历记录时出错: $e');
      setError('获取病历记录失败: $e');
      return null;
    } finally {
      setLoading(false);
    }
  }

  /// 创建新的病历记录
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 数据验证
      final validationError = validateMedicalRecord(record);
      if (validationError != null) {
        throw Exception('数据验证失败: $validationError');
      }

      // 权限检查和自动设置创建医生
      final currentUser = permissionService.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 自动设置创建医生字段为当前登录医生
      final recordWithCreator = record.copyWith(
        createdByDoctor: currentUser.doctor ?? currentUser.username,
      );

      // 非管理员用户只能创建自己的病历记录
      if (currentUser.role != 'admin' &&
          currentUser.doctor != null &&
          currentUser.doctor!.isNotEmpty &&
          recordWithCreator.doctorName != currentUser.doctor) {
        throw Exception('权限不足：只能创建自己的病历记录');
      }

      print('MedicalRecordService: 创建病历记录，患者ID: ${record.patientId}');

      final id = await dataSource.createMedicalRecord(recordWithCreator);

      if (id > 0) {
        print('MedicalRecordService: 病历记录创建成功，ID: $id');

        // 清除相关缓存
        cacheHelper.cachedMedicalRecords.remove(recordWithCreator.patientId);

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (syncService.needsSync) {
          print('MedicalRecordService: SQLite病历记录创建成功，开始同步到MySQL: 病历ID=$id');
          syncService.syncMedicalRecordToMySQL(recordWithCreator.copyWith(id: id).toMap(), id);
        }

        clearError();
        notifyListeners();
      } else {
        throw Exception('创建病历记录失败');
      }

      return id;
    } catch (e) {
      print('创建病历记录时出错: $e');
      setError('创建病历记录失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 更新病历记录
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 数据验证
      final validationError = validateMedicalRecord(record);
      if (validationError != null) {
        throw Exception('数据验证失败: $validationError');
      }

      // 权限检查
      final currentUser = permissionService.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 非管理员用户只能更新自己创建的病历记录
      if (currentUser.role != 'admin' &&
          currentUser.doctor != null &&
          currentUser.doctor!.isNotEmpty) {
        // 先获取原记录检查权限
        final originalRecord = await getMedicalRecordById(record.id!);
        if (originalRecord == null) {
          throw Exception('病历记录不存在');
        }

        // 检查是否是自己创建的病历记录
        final createdByDoctor = originalRecord.createdByDoctor ?? originalRecord.doctorName;
        if (createdByDoctor != currentUser.doctor) {
          throw Exception('权限不足：只能更新自己创建的病历记录');
        }
      }

      print('MedicalRecordService: 更新病历记录，ID: ${record.id}');

      final success = await dataSource.updateMedicalRecord(record);

      if (success) {
        print('MedicalRecordService: 病历记录更新成功');

        // 清除相关缓存
        cacheHelper.cachedMedicalRecords.remove(record.patientId);

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (syncService.needsSync) {
          print('MedicalRecordService: SQLite病历记录更新成功，开始同步到MySQL: 病历ID=${record.id}');
          syncService.syncMedicalRecordToMySQL(record.toMap(), record.id!);
        }

        clearError();
        notifyListeners();
      } else {
        throw Exception('更新病历记录失败');
      }

      return success;
    } catch (e) {
      print('更新病历记录时出错: $e');
      setError('更新病历记录失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 删除病历记录
  Future<bool> deleteMedicalRecord(int id) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      // 权限检查
      final currentUser = permissionService.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }

      // 非管理员用户只能删除自己创建的病历记录
      if (currentUser.role != 'admin' &&
          currentUser.doctor != null &&
          currentUser.doctor!.isNotEmpty) {
        // 先获取原记录检查权限
        final originalRecord = await getMedicalRecordById(id);
        if (originalRecord == null) {
          throw Exception('病历记录不存在');
        }

        // 检查是否是自己创建的病历记录
        final createdByDoctor = originalRecord.createdByDoctor ?? originalRecord.doctorName;
        if (createdByDoctor != currentUser.doctor) {
          throw Exception('权限不足：只能删除自己创建的病历记录');
        }
      }

      print('MedicalRecordService: 删除病历记录，ID: $id');

      // 先获取记录信息用于清除缓存
      final recordToDelete = await dataSource.getMedicalRecordById(id);

      final success = await dataSource.deleteMedicalRecord(id);

      if (success) {
        print('MedicalRecordService: 病历记录删除成功');

        // 清除相关缓存
        if (recordToDelete != null) {
          cacheHelper.cachedMedicalRecords.remove(recordToDelete.patientId);
        }

        if (syncService.needsSync) {
          print('MedicalRecordService: SQLite病历记录删除成功，开始同步删除到MySQL: 病历ID=$id');
          syncService.syncDeleteMedicalRecordToMySQL(id);
        }

        clearError();
        notifyListeners();
      } else {
        throw Exception('删除病历记录失败');
      }

      return success;
    } catch (e) {
      print('删除病历记录时出错: $e');
      setError('删除病历记录失败: $e');
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  /// 搜索病历记录
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId}) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    if (query.trim().isEmpty) {
      return [];
    }

    try {
      setLoading(true);

      print('MedicalRecordService: 搜索病历记录，关键词: $query');

      final records = await dataSource.searchMedicalRecords(query, patientId: patientId);
      clearError();
      return records;
    } catch (e) {
      print('搜索病历记录时出错: $e');
      setError('搜索病历记录失败: $e');
      return [];
    } finally {
      setLoading(false);
    }
  }

  /// 获取病历记录数量
  Future<int> getMedicalRecordsCount(int patientId) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      final count = await dataSource.getMedicalRecordsCount(patientId);
      clearError();
      return count;
    } catch (e) {
      print('获取病历记录数量时出错: $e');
      setError('获取病历记录数量失败: $e');
      return 0;
    }
  }

  /// 分页获取病历记录
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  }) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) {
      throw Exception('数据源未初始化');
    }

    try {
      setLoading(true);

      print('MedicalRecordService: 分页获取病历记录，患者ID: $patientId, 页码: $page');

      final result = await dataSource.getMedicalRecordsPage(
        patientId: patientId,
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        sortField: sortField,
        sortAscending: sortAscending,
      );

      print('MedicalRecordService: 分页查询成功，总数: ${result['totalCount']}, 当前页: ${result['records'].length}');

      clearError();
      return result;
    } catch (e) {
      print('分页获取病历记录时出错: $e');
      setError('分页获取病历记录失败: $e');
      return {
        'records': <PatientMedicalRecord>[],
        'totalCount': 0,
        'totalPages': 0,
        'currentPage': page,
      };
    } finally {
      setLoading(false);
    }
  }
}
