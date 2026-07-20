import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/features/patients/services/patient_form_validators.dart';

void main() {
  group('患者管理-添加患者字段校验', () {
    test('姓名为空时返回“请输入姓名”', () {
      expect(PatientFormValidators.validateName(null), '请输入姓名');
      expect(PatientFormValidators.validateName(''), '请输入姓名');
    });

    test('姓名非空时校验通过', () {
      expect(PatientFormValidators.validateName('张三'), isNull);
    });

    test('主治医生为空时返回提示', () {
      expect(PatientFormValidators.validateDoctor(null), '请先填写主治医生');
      expect(PatientFormValidators.validateDoctor('  '), '请先填写主治医生');
      expect(PatientFormValidators.validateDoctor('医生甲'), isNull);
    });

    test('年龄为空时校验通过', () {
      expect(PatientFormValidators.validateAge(null), isNull);
      expect(PatientFormValidators.validateAge(''), isNull);
    });

    test('年龄非数字时返回错误提示', () {
      expect(PatientFormValidators.validateAge('abc'), '请输入有效年龄');
      expect(PatientFormValidators.validateAge('12.5'), '请输入有效年龄');
    });

    test('年龄为整数时校验通过', () {
      expect(PatientFormValidators.validateAge('30'), isNull);
    });

    test('手机号为空时校验通过', () {
      expect(PatientFormValidators.validatePhone(null), isNull);
      expect(PatientFormValidators.validatePhone(''), isNull);
    });

    test('手机号格式不正确时返回错误提示', () {
      expect(
        PatientFormValidators.validatePhone('12345678901'),
        '请输入正确的11位手机号码',
      );
      expect(
        PatientFormValidators.validatePhone('1380013800'),
        '请输入正确的11位手机号码',
      );
    });

    test('合法11位手机号校验通过', () {
      expect(PatientFormValidators.validatePhone('13800138000'), isNull);
      expect(PatientFormValidators.validatePhone('15912345678'), isNull);
    });

    test('备用手机号为空时校验通过', () {
      expect(PatientFormValidators.validateOptionalPhone(null), isNull);
      expect(PatientFormValidators.validateOptionalPhone(''), isNull);
    });

    test('备用手机号格式错误时返回错误提示', () {
      expect(
        PatientFormValidators.validateOptionalPhone('123'),
        '请输入正确的11位手机号码',
      );
    });

    test('备用手机号合法时校验通过', () {
      expect(
          PatientFormValidators.validateOptionalPhone('13800138000'), isNull);
    });
  });
}
