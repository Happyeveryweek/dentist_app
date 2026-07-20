import 'patient.dart';
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';
import '../utils/map_parser.dart';
import 'appointment_status.dart';

class Appointment {
  final int? id;
  final int? patientId;
  Patient? patient; // 不再为final，允许后续设置
  final DateTime appointmentDate;
  final String? appointmentTime; // 预约时间
  final String status; // scheduled, completed, cancelled
  final String? treatmentType;
  final String? notes;
  final double? cost;
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    this.id,
    required this.patientId,
    this.patient,
    required this.appointmentDate,
    this.appointmentTime, // 预约时间
    required this.status,
    this.treatmentType,
    this.notes,
    this.cost,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 从Map创建Appointment对象
  factory Appointment.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'Appointment');

    return Appointment(
      id: p.optional('id', (v) => v as int),
      patientId: p.optional('patient_id', (v) => v as int),
      appointmentDate: _parseDateTime(map['appointment_date']),
      appointmentTime: _parseAppointmentTime(map['appointment_time']),
      status: AppointmentStatus.normalizeStorageValue(p.string('status')),
      treatmentType: p.optional('treatment_type', (v) => v.toString()),
      notes: p.optional('notes', (v) => v.toString()),
      cost: p.decimalOrNull('cost'),
      createdAt: p.dateTime('created_at'),
      updatedAt: p.dateTime('updated_at'),
    );
  }

  // 将Appointment对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'appointment_date': DateTimeFormatter.toDbString(appointmentDate),
      'appointment_time': appointmentTime ??
          _extractTimeFromDateTime(appointmentDate), // 确保总是有时间值
      'status': AppointmentStatus.normalizeStorageValue(status),
      if (treatmentType != null) 'treatment_type': treatmentType,
      if (notes != null) 'notes': notes,
      if (cost != null) 'cost': cost,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 辅助方法：从DateTime中提取时间字符串 (HH:MM:SS)
  String _extractTimeFromDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 创建具有新属性的Appointment副本
  Appointment copyWith({
    int? id,
    int? patientId,
    Patient? patient,
    DateTime? appointmentDate,
    String? appointmentTime, // 预约时间
    String? status,
    String? treatmentType,
    String? notes,
    double? cost,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patient: patient ?? this.patient,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime, // 预约时间
      status: status ?? this.status,
      treatmentType: treatmentType ?? this.treatmentType,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 帮助函数：解析日期时间字符串或处理DateTime对象
  static DateTime _parseDateTime(dynamic dateTime) {
    // 如果已经是DateTime类型，直接返回
    if (dateTime is DateTime) {
      return dateTime;
    }

    // 如果是字符串，使用统一的时间格式解析
    if (dateTime is String) {
      return DateTimeFormatter.fromDbString(dateTime);
    }

    // 如果无法解析，返回当前时间
    LogManager.e('Appointment', '无法解析日期时间: $dateTime，使用当前时间');
    return DateTime.now();
  }

  // 帮助函数：解析预约时间（处理Duration和String类型）
  static String? _parseAppointmentTime(dynamic timeValue) {
    if (timeValue == null) return null;

    // 如果已经是String类型，直接返回
    if (timeValue is String) {
      return timeValue;
    }

    // 如果是Duration类型（MySQL的TIME类型），转换为HH:MM:SS格式
    if (timeValue is Duration) {
      final hours = timeValue.inHours;
      final minutes = timeValue.inMinutes.remainder(60);
      final seconds = timeValue.inSeconds.remainder(60);
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    // 其他类型尝试转换为字符串
    return timeValue.toString();
  }

  // 获取状态显示名称
  String get statusDisplay {
    return AppointmentStatus.displayNameOf(status);
  }

  // 获取状态颜色
  String get statusColor {
    switch (AppointmentStatus.tryParse(status)) {
      case AppointmentStatus.scheduled:
        return '#2196F3'; // 蓝色
      case AppointmentStatus.completed:
        return '#4CAF50'; // 绿色
      case AppointmentStatus.cancelled:
        return '#F44336'; // 红色
      case AppointmentStatus.missed:
        return '#FF9800'; // 橙色
      case null:
        return '#9E9E9E'; // 灰色
    }
  }
}
