import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/patient.dart';
import '../../../models/appointment.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient_medical_record.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/appointment_provider.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/medical_record_provider.dart';

/// 患者详情页数据加载结果
class PatientDetailData {
  final Patient patient;
  final List<Appointment> appointments;
  final List<FinancialRecord> financialRecords;
  final List<FinancialItem> financialItems;
  final List<PatientMedicalRecord> medicalRecords;

  PatientDetailData({
    required this.patient,
    required this.appointments,
    required this.financialRecords,
    required this.financialItems,
    required this.medicalRecords,
  });
}

/// 患者详情页数据加载编排服务
///
/// 负责从各 Provider 获取并组装患者详情页需要的全部数据。
/// 不负责 UI、权限判断、状态管理。
class PatientDetailLoaderService {
  /// 加载患者详情页全部数据
  ///
  /// [context] 用于获取 Provider
  /// [patient] 传入的患者对象（至少包含 id）
  /// [canViewFinancialRecords] 是否有权限查看财务记录，由调用方判断
  static Future<PatientDetailData> load({
    required BuildContext context,
    required Patient patient,
    required bool canViewFinancialRecords,
  }) async {
    final patientProvider = Provider.of<PatientProvider>(context, listen: false);
    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
    final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);

    // 1. 从数据库重新获取最新的患者数据
    Patient? freshPatient;
    if (patient.id != null) {
      freshPatient = await patientProvider.getPatient(patient.id!);
      if (freshPatient == null) {
        print('无法从数据库获取患者数据，使用传入的患者对象');
        freshPatient = patient;
      } else {
        print('成功从数据库获取最新患者数据: ${freshPatient.name}');
      }
    } else {
      freshPatient = patient;
    }

    // 2. 读取患者预约数据
    final appointments = await appointmentProvider.getAppointmentsByPatient(patient.id!);

    // 3. 读取患者收费记录数据 - 只有有权限的用户才能加载
    List<FinancialRecord> patientFinancialRecords = [];
    List<FinancialItem> allFinancialItems = [];

    if (canViewFinancialRecords) {
      print('🔍 开始加载患者收费记录，患者ID: ${patient.id}');

      // 清除缓存，确保从数据库获取最新数据
      financialProvider.clearCache();

      // 使用不带权限过滤的方法，因为页面级别已经做了权限检查
      final allFinancialRecords = await financialProvider.getAllFinancialRecords();
      print('🔍 获取到所有收费记录数量: ${allFinancialRecords.length}');

      patientFinancialRecords = allFinancialRecords
          .where((record) => record.patientId == patient.id!)
          .toList();
      print('🔍 筛选后该患者的收费记录数量: ${patientFinancialRecords.length}');

      // 读取该患者的所有收费项目
      for (var record in patientFinancialRecords) {
        final items = await financialProvider.getFinancialItems(record.id!);
        allFinancialItems.addAll(items);
        print('🔍 收费记录 ${record.id} 包含 ${items.length} 个收费项目');
      }
      print('🔍 该患者总收费项目数量: ${allFinancialItems.length}');
    } else {
      print('🔍 权限检查失败，无法加载患者收费记录');
    }

    // 4. 读取患者病历数据
    List<PatientMedicalRecord> medicalRecords = [];
    try {
      if (medicalRecordProvider.initialized) {
        medicalRecords = await medicalRecordProvider.getPatientMedicalRecords(patient.id!);
      }
    } catch (e) {
      print('加载病历数据失败: $e');
      // 不阻止页面加载，只是病历数据为空
    }

    return PatientDetailData(
      patient: freshPatient,
      appointments: appointments,
      financialRecords: patientFinancialRecords,
      financialItems: allFinancialItems,
      medicalRecords: medicalRecords,
    );
  }

  /// 仅加载病历数据（供刷新时使用）
  static Future<List<PatientMedicalRecord>> loadMedicalRecords({
    required BuildContext context,
    required int patientId,
  }) async {
    final medicalRecordProvider = Provider.of<MedicalRecordProvider>(context, listen: false);
    List<PatientMedicalRecord> medicalRecords = [];
    try {
      if (medicalRecordProvider.initialized) {
        medicalRecords = await medicalRecordProvider.getPatientMedicalRecords(patientId);
      }
    } catch (e) {
      print('加载病历数据失败: $e');
    }
    return medicalRecords;
  }
}
