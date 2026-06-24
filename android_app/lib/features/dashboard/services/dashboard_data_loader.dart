import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/appointments_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../models/database_models.dart';
import '../../../utils/app_logger.dart';

/// 仪表盘数据加载服务
class DashboardDataLoader {
  /// 加载仪表盘数据
  static Future<DashboardData> loadData(BuildContext context) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );
    final appointmentsProvider = Provider.of<AppointmentsProvider>(
      context,
      listen: false,
    );
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // 确保数据库已初始化
    if (!dbProvider.isInitialized) {
      AppLogger.info('数据库未初始化，正在初始化...');
      try {
        await dbProvider.initDatabase();
        await Future.delayed(const Duration(milliseconds: 500));
        AppLogger.info('数据库初始化完成');
      } catch (e) {
        AppLogger.info('尝试初始化数据库时出错: $e');
        AppLogger.info('尝试再次初始化数据库...');
        await Future.delayed(const Duration(seconds: 1));
        await dbProvider.initDatabase();
      }
    } else {
      AppLogger.info('数据库已初始化');
    }

    // 确保所有Provider都初始化完成
    await _initializeAllProviders(
      dbProvider,
      patientProvider,
      appointmentsProvider,
      userProvider,
    );

    // 获取患者数量
    int patientCount = 0;
    try {
      AppLogger.info('正在获取患者数量...');
      patientCount = await patientProvider.getPatientCount();
      AppLogger.info('成功获取患者数量: $patientCount，数据库类型: ${dbProvider.dbType}');
    } catch (e) {
      AppLogger.info('获取患者数量错误: $e');
    }

    // 获取预约数量
    int appointmentCount = 0;
    try {
      AppLogger.info('正在获取预约数量...');
      appointmentCount = await appointmentsProvider.getAppointmentCount();
      AppLogger.info('成功获取预约数量: $appointmentCount，数据库类型: ${dbProvider.dbType}');
    } catch (e) {
      AppLogger.info('获取预约数量错误: $e');
    }

    // 获取今日预约
    List<Appointment> todayAppointments = [];
    try {
      AppLogger.info('正在获取今日预约...');
      todayAppointments = await appointmentsProvider.getTodayAppointments();
      AppLogger.info('成功获取今日预约: ${todayAppointments.length}');
    } catch (e) {
      AppLogger.info('获取今日预约错误: $e');
    }

    // 计算已完成和即将到来的预约数
    int completed = 0;
    int upcoming = 0;
    try {
      AppLogger.info('正在获取所有预约...');
      final allAppointments = await appointmentsProvider.getAllAppointments();
      AppLogger.info('成功获取所有预约: ${allAppointments.length}');

      for (var appointment in allAppointments) {
        if (appointment.status == 'completed') {
          completed++;
        } else if (appointment.status == 'scheduled' &&
            appointment.appointmentDate.isAfter(DateTime.now())) {
          upcoming++;
        }
      }
      AppLogger.info('已完成预约: $completed, 即将到来的预约: $upcoming');
    } catch (e) {
      AppLogger.info('获取所有预约错误: $e');
    }

    return DashboardData(
      patientCount: patientCount,
      appointmentCount: appointmentCount,
      todayAppointments: todayAppointments,
      completedAppointments: completed,
      upcomingAppointments: upcoming,
    );
  }

  /// 确保所有Provider都初始化完成
  static Future<void> _initializeAllProviders(
    DatabaseProvider dbProvider,
    PatientProvider patientProvider,
    AppointmentsProvider appointmentsProvider,
    UserProvider userProvider,
  ) async {
    try {
      AppLogger.info('开始初始化所有Provider...');

      if (!patientProvider.initialized) {
        await patientProvider.initializeFromDatabase(dbProvider);
        AppLogger.info('PatientProvider初始化完成');
      }

      if (!appointmentsProvider.initialized) {
        await appointmentsProvider.initializeFromDatabase(
          dbProvider,
          userProvider: userProvider,
        );
        AppLogger.info('AppointmentsProvider初始化完成');
      }

      AppLogger.info('所有Provider初始化完成');
    } catch (e) {
      AppLogger.info('初始化Provider时出错: $e');
    }
  }
}

/// 仪表盘数据类
class DashboardData {
  final int patientCount;
  final int appointmentCount;
  final List<Appointment> todayAppointments;
  final int completedAppointments;
  final int upcomingAppointments;

  DashboardData({
    required this.patientCount,
    required this.appointmentCount,
    required this.todayAppointments,
    required this.completedAppointments,
    required this.upcomingAppointments,
  });
}
