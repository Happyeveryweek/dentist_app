import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

class Appointment {
  final int? id;
  final int? patientId;
  final DateTime appointmentDate;
  final String? appointmentTime;
  final String status; // scheduled, completed, cancelled
  final String? treatmentType;
  final String? notes;
  final double? cost;
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    this.id,
    required this.patientId,
    required this.appointmentDate,
    this.appointmentTime,
    required this.status,
    this.treatmentType,
    this.notes,
    this.cost,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // 从Map创建Appointment对象
  factory Appointment.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'Appointment');
    return Appointment(
      id: p.optional('id', (v) => v as int),
      patientId: p.integerOptional('patient_id'),
      appointmentDate: p.dateTime('appointment_date'),
      appointmentTime: p.stringOptional('appointment_time'),
      status: p.string('status', defaultValue: 'scheduled'),
      treatmentType: p.stringOptional('treatment_type'),
      notes: p.stringOptional('notes'),
      cost: p.doubleOptional('cost'),
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
      if (appointmentTime != null) 'appointment_time': appointmentTime,
      'status': status,
      if (treatmentType != null) 'treatment_type': treatmentType,
      if (notes != null) 'notes': notes,
      if (cost != null) 'cost': cost,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 创建具有新属性的Appointment副本
  Appointment copyWith({
    int? id,
    int? patientId,
    DateTime? appointmentDate,
    String? appointmentTime,
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
      appointmentDate: appointmentDate ?? this.appointmentDate,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      status: status ?? this.status,
      treatmentType: treatmentType ?? this.treatmentType,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 获取状态显示名称
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return '已预约';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      case 'missed':
        return '未到诊';
      default:
        return status;
    }
  }

  // 获取状态颜色
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case '已预约':
        return '#2196F3'; // 蓝色
      case 'completed':
      case '已完成':
        return '#4CAF50'; // 绿色
      case 'cancelled':
      case '已取消':
        return '#F44336'; // 红色
      case 'missed':
      case '未到诊':
        return '#FF9800'; // 橙色
      default:
        return '#9E9E9E'; // 灰色
    }
  }
}
