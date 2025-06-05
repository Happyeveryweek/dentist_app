import 'package:intl/intl.dart';
import 'patient.dart';

class Appointment {
  final int? id;
  final int? patient_id;
  Patient? patient; // 不再为final，允许后续设置
  final DateTime appointment_date;
  final String status; // scheduled, completed, cancelled
  final String? treatment_type;
  final String? notes;
  final double? cost;
  final DateTime created_at;
  final DateTime updated_at;

  Appointment({
    this.id,
    required this.patient_id,
    this.patient,
    required this.appointment_date,
    required this.status,
    this.treatment_type,
    this.notes,
    this.cost,
    DateTime? created_at,
    DateTime? updated_at,
  })  : created_at = created_at ?? DateTime.now(),
        updated_at = updated_at ?? DateTime.now();

  // 从Map创建Appointment对象
  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'],
      patient_id: map['patient_id'],
      appointment_date: _parseDateTime(map['appointment_date']),
      status: map['status'] ?? '',
      treatment_type: map['treatment_type'],
      notes: map['notes'],
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      created_at:
          map['created_at'] != null ? _parseDateTime(map['created_at']) : null,
      updated_at:
          map['updated_at'] != null ? _parseDateTime(map['updated_at']) : null,
    );
  }

  // 将Appointment对象转换为Map
  Map<String, dynamic> toMap() {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return {
      if (id != null) 'id': id,
      'patient_id': patient_id,
      'appointment_date': dateFormat.format(appointment_date),
      'status': status,
      if (treatment_type != null) 'treatment_type': treatment_type,
      if (notes != null) 'notes': notes,
      if (cost != null) 'cost': cost,
      'created_at': created_at != null
          ? dateFormat.format(created_at!)
          : dateFormat.format(DateTime.now()),
      'updated_at': updated_at != null
          ? dateFormat.format(updated_at!)
          : dateFormat.format(DateTime.now()),
    };
  }

  // 创建具有新属性的Appointment副本
  Appointment copyWith({
    int? id,
    int? patient_id,
    Patient? patient,
    DateTime? appointment_date,
    String? status,
    String? treatment_type,
    String? notes,
    double? cost,
    DateTime? created_at,
    DateTime? updated_at,
  }) {
    return Appointment(
      id: id ?? this.id,
      patient_id: patient_id ?? this.patient_id,
      patient: patient ?? this.patient,
      appointment_date: appointment_date ?? this.appointment_date,
      status: status ?? this.status,
      treatment_type: treatment_type ?? this.treatment_type,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
    );
  }

  // 帮助函数：解析日期时间字符串或处理DateTime对象
  static DateTime _parseDateTime(dynamic dateTime) {
    // 如果已经是DateTime类型，直接返回
    if (dateTime is DateTime) {
      return dateTime;
    }

    // 如果是字符串，尝试解析
    if (dateTime is String) {
      try {
        // 首先尝试解析标准格式
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime);
      } catch (e) {
        // 尝试解析ISO格式
        try {
          return DateTime.parse(dateTime);
        } catch (e) {
          // 尝试其他常见格式
          try {
            return DateFormat('yyyy-MM-dd').parse(dateTime);
          } catch (e) {
            print('日期解析错误: $e，使用当前时间');
            return DateTime.now();
          }
        }
      }
    }

    // 如果无法解析，返回当前时间
    print('无法解析日期时间: $dateTime，使用当前时间');
    return DateTime.now();
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

  // 为了向后兼容添加的getter
  int? get patientId => patient_id;
  DateTime get appointmentDate => appointment_date;
  String? get treatmentType => treatment_type;
  DateTime? get createdAt => created_at;
  DateTime? get updatedAt => updated_at;
}
