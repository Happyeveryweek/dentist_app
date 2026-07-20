import '../../../models/user.dart';

/// 解析新增患者可用的默认主治医生。
class PatientDefaultDoctorResolver {
  PatientDefaultDoctorResolver._();

  static String? resolve(User? currentUser) {
    final doctor = currentUser?.doctor?.trim();
    return doctor == null || doctor.isEmpty ? null : doctor;
  }
}
