import 'package:flutter/material.dart';

/// 患者表单字段校验器
///
/// 将患者添加/编辑表单中的校验逻辑集中到这里，便于单元测试和复用。
class PatientFormValidators {
  PatientFormValidators._();

  /// 校验姓名：不能为空
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入姓名';
    }
    return null;
  }

  /// 校验年龄：非必填，但填写时必须是有效整数
  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) return null;
    if (int.tryParse(value) == null) {
      return '请输入有效年龄';
    }
    return null;
  }

  /// 校验手机号：非必填，但填写时必须是合法11位手机号
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    final RegExp phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return '请输入正确的11位手机号码';
    }
    return null;
  }

  /// 校验备用手机号：非必填，填写时走手机号校验
  static String? validateOptionalPhone(String? value) {
    if (value != null && value.isNotEmpty) {
      return validatePhone(value);
    }
    return null;
  }

  /// 从 TextEditingController 安全读取文本并 trim
  static String _trimmedText(TextEditingController controller) {
    return controller.text.trim();
  }

  /// 校验主手机号 Controller
  static String? validatePrimaryPhoneController(TextEditingController controller) {
    return validatePhone(_trimmedText(controller));
  }

  /// 校验备用手机号 Controller
  static String? validateBackupPhoneController(TextEditingController controller) {
    return validateOptionalPhone(_trimmedText(controller));
  }
}
