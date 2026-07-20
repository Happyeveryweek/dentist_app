import 'package:dentist_app_windows/features/patients/services/patient_default_doctor_resolver.dart';
import 'package:dentist_app_windows/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  User user({String? doctor, String username = 'login-name'}) => User(
        username: username,
        password: 'password',
        role: 'doctor',
        doctor: doctor,
      );

  group('PatientDefaultDoctorResolver', () {
    test('仅使用当前用户已配置且裁剪后的医生姓名', () {
      expect(
          PatientDefaultDoctorResolver.resolve(user(doctor: ' 医生甲 ')), '医生甲');
    });

    test('医生姓名缺失时不回退用户名', () {
      expect(PatientDefaultDoctorResolver.resolve(user()), isNull);
      expect(PatientDefaultDoctorResolver.resolve(user(doctor: '  ')), isNull);
      expect(PatientDefaultDoctorResolver.resolve(null), isNull);
    });
  });
}
