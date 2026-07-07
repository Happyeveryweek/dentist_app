import 'package:flutter/material.dart';

import '../../../models/dental_chart.dart';
import '../../../models/patient.dart';

/// 患者表单状态数据对象
/// 从 _PatientFormDialogState 中提取，集中管理表单控制器和状态变量
class PatientFormState {
  // 表单 Key
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // 文本控制器
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController primaryPhoneController = TextEditingController();
  final TextEditingController backupPhoneController = TextEditingController();
  final TextEditingController medicalRecordController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController doctorController = TextEditingController();
  final TextEditingController treatmentItemsController =
      TextEditingController();

  // 滚动控制器
  final ScrollController scrollController = ScrollController();

  // 姓名输入框的 GlobalKey，用于精确定位同名患者弹窗
  final GlobalKey nameFieldKey = GlobalKey();

  // 基本状态
  bool hasBackupPhone = false;
  DateTime firstVisitDate;
  String gender = '男'; // 默认性别

  // 牙齿状况十字图相关
  List<DentalChartRow> dentalChartRows = [];

  // 同名患者检查相关
  String? nameExistsError;
  Patient? existingPatient;
  Patient? editingExistingPatient; // 从同名患者填充后追踪编辑状态

  // 保存状态
  bool isLoading = false;

  // 权限控制
  bool canEditBasicInfo = true;

  PatientFormState({DateTime? firstVisitDate})
      : firstVisitDate = firstVisitDate ?? DateTime.now();

  /// 释放所有控制器
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    primaryPhoneController.dispose();
    backupPhoneController.dispose();
    medicalRecordController.dispose();
    addressController.dispose();
    idNumberController.dispose();
    doctorController.dispose();
    treatmentItemsController.dispose();
    scrollController.dispose();
    for (var row in dentalChartRows) {
      row.dispose();
    }
  }

  /// 从已有患者加载基本信息到控制器
  void loadFromPatient(Patient patient) {
    nameController.text = patient.name;
    ageController.text = patient.age.toString();
    gender = patient.gender;
    medicalRecordController.text =
        patient.medicalRecordNumber?.toString() ?? '';
    addressController.text = patient.address ?? '';
    idNumberController.text = patient.identificationNumber ?? '';
    doctorController.text = patient.doctor ?? '';
    treatmentItemsController.text = patient.treatmentItems ?? '';
    firstVisitDate = patient.firstVisitDate;
  }

  /// 构建电话号码数据
  /// 返回适合存入 Patient.phone 的值
  dynamic buildPhoneData() {
    if (primaryPhoneController.text.isEmpty &&
        (!hasBackupPhone || backupPhoneController.text.isEmpty)) {
      return '';
    } else if (hasBackupPhone && backupPhoneController.text.isNotEmpty) {
      // 注意：这里返回 JSON 编码字符串，调用方需要 import dart:convert
      return [
        primaryPhoneController.text,
        backupPhoneController.text,
      ];
    } else {
      return primaryPhoneController.text;
    }
  }

  /// 获取排除当前编辑患者的 ID（用于重复检查）
  int? get excludePatientId => editingExistingPatient?.id;
}
