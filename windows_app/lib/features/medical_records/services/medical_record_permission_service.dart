import '../../../models/user.dart';
import '../../../models/patient_medical_record.dart';
import '../../../providers/user_provider.dart';

/// 病历权限检查服务
/// 负责处理病历记录的权限检查逻辑
class MedicalRecordPermissionService {
  final UserProvider? Function()? getUserProvider;
  final User? Function()? getCurrentUser;
  final Future<PatientMedicalRecord?> Function(int) getMedicalRecordById;

  MedicalRecordPermissionService({
    this.getUserProvider,
    this.getCurrentUser,
    required this.getMedicalRecordById,
  });

  /// 检查病历记录操作权限
  Future<void> checkMedicalRecordPermission(int recordId) async {
    final currentUser =
        getUserProvider?.call()?.currentUser ?? getCurrentUser?.call();
    if (currentUser == null) {
      throw Exception('用户未登录');
    }

    // 管理员拥有所有权限
    if (currentUser.role == 'admin') {
      return;
    }

    // 非管理员用户需要检查是否是自己创建的病历记录
    if (currentUser.doctor?.isNotEmpty == true) {
      final record = await getMedicalRecordById(recordId);
      if (record == null) {
        throw Exception('病历记录不存在');
      }

      // 检查是否是自己创建的病历记录
      final createdByDoctor = record.createdByDoctor ?? record.doctorName;
      if (createdByDoctor != currentUser.doctor) {
        throw Exception('权限不足：只能操作自己创建的病历记录');
      }
    } else {
      throw Exception('权限不足：用户没有医生权限');
    }
  }

  /// 检查当前用户是否有权限操作指定病历记录
  Future<bool> hasPermissionForRecord(int recordId) async {
    try {
      await checkMedicalRecordPermission(recordId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 检查当前用户是否为管理员
  bool get isCurrentUserAdmin {
    final currentUser =
        getUserProvider?.call()?.currentUser ?? getCurrentUser?.call();
    return currentUser?.role == 'admin';
  }

  /// 获取当前用户的医生名称
  String? get currentDoctorName {
    final currentUser =
        getUserProvider?.call()?.currentUser ?? getCurrentUser?.call();
    return currentUser?.doctor;
  }

  /// 获取当前用户
  User? get currentUser {
    return getUserProvider?.call()?.currentUser ?? getCurrentUser?.call();
  }
}
