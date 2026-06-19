import 'dart:typed_data';
import 'package:dentist_app_windows/providers/database_provider.dart';
import 'package:dentist_app_windows/providers/appointment_provider.dart';
import 'package:dentist_app_windows/providers/patient_provider.dart';
import 'package:dentist_app_windows/providers/user_provider.dart';
import 'package:dentist_app_windows/models/patient.dart';
import 'package:dentist_app_windows/models/appointment.dart';
import '../helpers/dashboard_status_helper.dart';

/// 仪表盘数据
class DashboardData {
  final int patientCount;
  final int appointmentCount;
  final int completedAppointments;
  final int upcomingAppointments;
  final int todayAppointmentsCount;
  final int todayScheduledAppointments;
  final int todayCompletedAppointments;
  final int todayUnfinishedAppointments;
  final List<Appointment> todayAppointments;
  final List<Patient> recentPatients;
  final String currentUserName;
  final Uint8List? currentUserAvatar;

  DashboardData({
    required this.patientCount,
    required this.appointmentCount,
    required this.completedAppointments,
    required this.upcomingAppointments,
    required this.todayAppointmentsCount,
    required this.todayScheduledAppointments,
    required this.todayCompletedAppointments,
    required this.todayUnfinishedAppointments,
    required this.todayAppointments,
    required this.recentPatients,
    required this.currentUserName,
    required this.currentUserAvatar,
  });
}

/// 仪表盘数据服务
/// 职责：仪表盘数据加载、权限过滤、日期过滤、排序
class DashboardDataService {
  final PatientProvider _patientProvider;
  final AppointmentProvider _appointmentProvider;
  final DatabaseProvider _databaseProvider;
  final UserProvider _userProvider;

  DashboardDataService({
    required PatientProvider patientProvider,
    required AppointmentProvider appointmentProvider,
    required DatabaseProvider databaseProvider,
    required UserProvider userProvider,
  })  : _patientProvider = patientProvider,
        _appointmentProvider = appointmentProvider,
        _databaseProvider = databaseProvider,
        _userProvider = userProvider;

  /// 加载仪表盘数据
  Future<DashboardData> loadData() async {
    // 获取当前用户信息（优先从UserProvider获取）
    final currentUser = _userProvider.currentUser ?? await _databaseProvider.getCurrentUser();
    // 优先使用医生姓名，如果没有则使用用户名
    final currentUserName = currentUser?.doctor?.isNotEmpty == true 
        ? currentUser!.doctor! 
        : (currentUser?.username ?? '');
    
    // 获取用户头像
    Uint8List? currentUserAvatar;
    final imageData = currentUser?.imageData;
    if (imageData != null && imageData.isNotEmpty) {
      currentUserAvatar = Uint8List.fromList(imageData);
    } else {
      currentUserAvatar = null;
    }
    
    // 获取统计数据（已通过Provider自动应用权限过滤）
    final patients = await _patientProvider.getAllPatients();
    final appointments = await _appointmentProvider.getAllAppointments();
    
    // 记录权限过滤信息
    if (currentUser != null && !currentUser.isAdmin) {
      print('仪表盘数据权限过滤: 用户=${currentUser.username}, 医生=${currentUser.doctor}, 患者数=${patients.length}, 预约数=${appointments.length}');
    } else {
      print('仪表盘数据无权限过滤: 管理员用户或未登录, 患者数=${patients.length}, 预约数=${appointments.length}');
    }
    
    // 获取今日预约
    final today = DateTime.now();
    final todayAppointments = appointments.where((appointment) {
      final appointmentDate = appointment.appointment_date;
      return appointmentDate.year == today.year &&
          appointmentDate.month == today.month &&
          appointmentDate.day == today.day;
    }).toList();

    // 按时间排序今日预约
    todayAppointments.sort((a, b) => a.appointment_date.compareTo(b.appointment_date));

    final todayScheduledAppointments =
        todayAppointments.where((appointment) => DashboardStatusHelper.isScheduled(appointment.status)).length;
    final todayCompletedAppointments =
        todayAppointments.where((appointment) => DashboardStatusHelper.isCompleted(appointment.status)).length;
    final todayUnfinishedAppointments =
        todayAppointments.where((appointment) => DashboardStatusHelper.isUnfinished(appointment.status)).length;

    // 获取最近的患者（按更新时间排序）
    final recentPatients = List<Patient>.from(patients);
    recentPatients.sort((a, b) => b.updated_at.compareTo(a.updated_at));

    // 计算完成和即将到来的预约
    final completed = appointments.where((a) => DashboardStatusHelper.isCompleted(a.status)).length;
    final upcoming = appointments.where((a) =>
      a.appointment_date.isAfter(DateTime.now()) &&
      DashboardStatusHelper.isScheduled(a.status)).length;

    return DashboardData(
      patientCount: patients.length,
      appointmentCount: appointments.length,
      completedAppointments: completed,
      upcomingAppointments: upcoming,
      todayAppointmentsCount: todayAppointments.length,
      todayScheduledAppointments: todayScheduledAppointments,
      todayCompletedAppointments: todayCompletedAppointments,
      todayUnfinishedAppointments: todayUnfinishedAppointments,
      todayAppointments: todayAppointments.take(5).toList(),
      recentPatients: recentPatients.take(5).toList(),
      currentUserName: currentUserName,
      currentUserAvatar: currentUserAvatar,
    );
  }
}
