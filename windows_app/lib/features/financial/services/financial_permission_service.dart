import '../../../models/financial_record.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/log_manager.dart';

/// 财务权限过滤服务
/// 负责根据用户权限过滤财务记录
class FinancialPermissionService {
  final PatientProvider? patientProvider;
  final UserProvider? userProvider;

  FinancialPermissionService({
    this.patientProvider,
    this.userProvider,
  });

  /// 获取医生过滤条件（用于数据库层面过滤）
  String? getDoctorFilter() {
    try {
      final provider = userProvider;
      // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (provider == null) {
        return null;
      }
      final currentUser = provider.currentUser;
      if (currentUser == null || currentUser.isAdmin) {
        return null; // 管理员不过滤
      }

      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回一个不存在的值，确保查询结果为空
        return '__NO_DOCTOR__';
      }

      return doctorName;
    } catch (e) {
      LogManager.e('FinancialPermissionService', '获取医生过滤条件失败', error: e);
      // 出错时返回安全的过滤条件
      return '__NO_DOCTOR__';
    }
  }

  /// 应用权限过滤（通过患者医生字段过滤财务记录）
  Future<List<FinancialRecord>> applyPermissionFilter(
      List<FinancialRecord> records) async {
    try {
      final provider = userProvider;
      final patientProv = patientProvider;
      // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (provider == null) {
        return records;
      }

      final currentUser = provider.currentUser;
      if (currentUser == null || currentUser.isAdmin) {
        return records;
      }

      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空列表

        return [];
      }

      // 过滤财务记录：只显示患者医生字段匹配的记录
      List<FinancialRecord> filteredRecords = [];

      if (patientProv != null) {
        for (final record in records) {
          // 通过患者提供者获取患者信息
          final patient = await patientProv.getPatient(record.patientId);
          if (patient != null && patient.doctor == doctorName) {
            filteredRecords.add(record);
          }
        }
      }

      return filteredRecords;
    } catch (e) {
      LogManager.e('FinancialPermissionService', '应用财务记录权限过滤失败', error: e);
      // 出错时返回空列表，确保安全
      return [];
    }
  }
}
