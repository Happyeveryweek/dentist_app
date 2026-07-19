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
import '../../../utils/log_manager.dart';

/// 患者详情页数据加载结果
class PatientDetailData {
  final Patient patient;
  final Patient? appointmentContextPatient;
  final Patient? financialContextPatient;
  final List<Appointment> appointments;
  final List<FinancialRecord> financialRecords;
  final List<FinancialItem> financialItems;
  final List<PatientMedicalRecord> medicalRecords;

  PatientDetailData({
    required this.patient,
    required this.appointmentContextPatient,
    required this.financialContextPatient,
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
    final patientProvider =
        Provider.of<PatientProvider>(context, listen: false);
    final appointmentProvider =
        Provider.of<AppointmentProvider>(context, listen: false);
    final financialProvider =
        Provider.of<FinancialProvider>(context, listen: false);
    final medicalRecordProvider =
        Provider.of<MedicalRecordProvider>(context, listen: false);

    final patientId = patient.id;
    if (patientId == null) {
      return PatientDetailData(
        patient: patient,
        appointmentContextPatient: null,
        financialContextPatient: null,
        appointments: [],
        financialRecords: [],
        financialItems: [],
        medicalRecords: [],
      );
    }

    // 1. 从数据库重新获取最新的患者数据
    Patient? freshPatient;
    freshPatient = await patientProvider.getPatient(patientId);
    if (freshPatient == null) {
      LogManager.e('PatientDetailData', '无法从数据库获取患者数据，使用传入的患者对象');
      freshPatient = patient;
    }

    // 2. 读取患者预约数据
    final patientDataSourceType = patientProvider.dataSourceType;
    final appointmentDataSourceType = appointmentProvider.dataSourceType;
    Patient? appointmentContextPatient = freshPatient;
    List<Appointment> appointments = [];

    if (patientDataSourceType != appointmentDataSourceType) {
      appointmentContextPatient =
          await patientProvider.resolvePatientForDataSource(
        freshPatient,
        targetDataSourceType: appointmentDataSourceType,
      );
      if (appointmentContextPatient == null) {
        LogManager.w(
          'PatientDetailData',
          '患者详情页未能在预约数据源中匹配到同一患者，已阻止错误预约关联: '
              'patientId=$patientId, patientDataSource=$patientDataSourceType, appointmentDataSource=$appointmentDataSourceType',
        );
      } else if (appointmentContextPatient.id != patientId) {
        LogManager.w(
          'PatientDetailData',
          '患者详情页预约患者已按业务标识重映射: '
              'sourcePatientId=$patientId -> appointmentPatientId=${appointmentContextPatient.id}',
        );
      }
    }

    final resolvedAppointmentPatientId = appointmentContextPatient?.id;
    if (resolvedAppointmentPatientId != null) {
      appointments = await appointmentProvider
          .getAppointmentsByPatient(resolvedAppointmentPatientId);
    }

    // 3. 读取患者收费记录数据 - 只有有权限的用户才能加载
    Patient? financialContextPatient;
    List<FinancialRecord> patientFinancialRecords = [];
    List<FinancialItem> allFinancialItems = [];

    if (canViewFinancialRecords) {
      final patientDataSourceType = patientProvider.dataSourceType;
      final financialDataSourceType = financialProvider.dataSourceType;
      financialContextPatient = freshPatient;
      int financialPatientId = patientId;

      if (patientDataSourceType != financialDataSourceType) {
        financialContextPatient =
            await patientProvider.resolvePatientForDataSource(
          freshPatient,
          targetDataSourceType: financialDataSourceType,
        );
        if (financialContextPatient == null) {
          LogManager.w(
            'PatientDetailData',
            '患者详情页未能在财务数据源中匹配到同一患者，已阻止错误财务关联: '
                'patientId=$patientId, patientDataSource=$patientDataSourceType, financialDataSource=$financialDataSourceType',
          );
        } else if (financialContextPatient.id != patientId) {
          LogManager.w(
            'PatientDetailData',
            '患者详情页财务患者已按业务标识重映射: '
                'sourcePatientId=$patientId -> financialPatientId=${financialContextPatient.id}',
          );
        }
      }

      final resolvedFinancialPatientId = financialContextPatient?.id;
      if (resolvedFinancialPatientId != null) {
        financialPatientId = resolvedFinancialPatientId;

        // 清除缓存，确保从数据库获取最新数据
        financialProvider.clearCache();

        // 使用不带权限过滤的方法，因为页面级别已经做了权限检查
        patientFinancialRecords = await financialProvider
            .getFinancialRecordsByPatientId(financialPatientId);

        // 读取该患者的所有收费项目
        for (var record in patientFinancialRecords) {
          final recordId = record.id;
          if (recordId == null) continue;
          final items =
              await financialProvider.getFinancialItemsByRecordId(recordId);
          allFinancialItems.addAll(items);
        }
      }
    } else {
      LogManager.e('PatientDetailData', '🔍 权限检查失败，无法加载患者收费记录');
    }

    // 4. 读取患者病历数据
    List<PatientMedicalRecord> medicalRecords = [];
    try {
      if (medicalRecordProvider.initialized) {
        medicalRecords =
            await medicalRecordProvider.getPatientMedicalRecords(patientId);
      }
    } catch (e) {
      LogManager.e('PatientDetailData', '加载病历数据失败', error: e);
      // 不阻止页面加载，只是病历数据为空
    }

    return PatientDetailData(
      patient: freshPatient,
      appointmentContextPatient: appointmentContextPatient,
      financialContextPatient: financialContextPatient,
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
    final medicalRecordProvider =
        Provider.of<MedicalRecordProvider>(context, listen: false);
    List<PatientMedicalRecord> medicalRecords = [];
    try {
      if (medicalRecordProvider.initialized) {
        medicalRecords =
            await medicalRecordProvider.getPatientMedicalRecords(patientId);
      }
    } catch (e) {
      LogManager.e('PatientDetailData', '加载病历数据失败', error: e);
    }
    return medicalRecords;
  }
}
