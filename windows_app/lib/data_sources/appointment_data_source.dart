import '../models/appointment.dart';
import '../providers/patient_provider.dart';

export 'sqlite_appointment_data_source.dart';
export 'mysql_appointment_data_source.dart';

/// 抽象预约数据源接口
/// 定义了所有预约管理相关的底层数据库操作协议
abstract class AppointmentDataSource {
  /// 设置患者提供者（用于获取患者信息）
  void setPatientProvider(PatientProvider patientProvider);
  
  Future<List<Appointment>> getAllAppointments();
  Future<Appointment?> getAppointmentById(int id);
  Future<int> createAppointment(Appointment appointment);
  Future<bool> updateAppointment(Appointment appointment);
  Future<bool> deleteAppointment(int id);
  
  // 查询方法
  Future<List<Appointment>> getAppointmentsByDate(DateTime date);
  Future<List<Appointment>> getAppointmentsByPatient(int patientId);
  Future<List<Appointment>> getAppointmentsByDoctor(String doctorName);
  Future<List<Appointment>> getTodayAppointments({String? doctorName});
  
  // 分页查询方法
  Future<int> getAppointmentsCount({String? searchQuery});
  Future<List<Appointment>> getPaginatedAppointments({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'appointment_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? filterDate,
    String? filterDoctor,
  });
  
  // 统计方法
  Future<Map<String, dynamic>> getAppointmentStatistics();
}
