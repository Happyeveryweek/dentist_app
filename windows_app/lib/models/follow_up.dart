import 'package:intl/intl.dart';
import 'patient.dart';

class FollowUp {
  final int? id;
  final int patient_id;
  Patient? patient;
  final DateTime follow_up_date;
  final String? notes;
  final DateTime created_at;
  final DateTime updated_at;

  FollowUp({
    this.id,
    required this.patient_id,
    this.patient,
    required this.follow_up_date,
    this.notes,
    DateTime? created_at,
    DateTime? updated_at,
  })  : created_at = created_at ?? DateTime.now(),
        updated_at = updated_at ?? DateTime.now();

  // 从Map创建FollowUp对象
  factory FollowUp.fromMap(Map<String, dynamic> map) {
    return FollowUp(
      id: map['id'],
      patient_id: map['patient_id'],
      follow_up_date: _parseDateTime(map['follow_up_date']),
      notes: map['notes'],
      created_at:
          map['created_at'] != null ? _parseDateTime(map['created_at']) : null,
      updated_at:
          map['updated_at'] != null ? _parseDateTime(map['updated_at']) : null,
    );
  }

  // 将FollowUp对象转换为Map
  Map<String, dynamic> toMap() {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return {
      if (id != null) 'id': id,
      'patient_id': patient_id,
      'follow_up_date': dateFormat.format(follow_up_date),
      'notes': notes,
      'created_at': dateFormat.format(created_at),
      'updated_at': dateFormat.format(updated_at),
    };
  }

  // 创建具有新属性的FollowUp副本
  FollowUp copyWith({
    int? id,
    int? patient_id,
    Patient? patient,
    DateTime? follow_up_date,
    String? notes,
    DateTime? created_at,
    DateTime? updated_at,
  }) {
    return FollowUp(
      id: id ?? this.id,
      patient_id: patient_id ?? this.patient_id,
      patient: patient ?? this.patient,
      follow_up_date: follow_up_date ?? this.follow_up_date,
      notes: notes ?? this.notes,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
    );
  }

  // 解析日期时间字符串
  static DateTime _parseDateTime(String dateTimeStr) {
    try {
      // 首先尝试解析标准格式
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTimeStr);
      // 确保使用本地时间
      return date.toLocal();
    } catch (e) {
      // 尝试解析ISO格式
      try {
        final date = DateTime.parse(dateTimeStr);
        // 确保使用本地时间
        return date.toLocal();
      } catch (e) {
        // 尝试其他常见格式
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateTimeStr);
          // 确保使用本地时间
          return date.toLocal();
        } catch (e) {
          // 如果无法解析，返回当前时间
          return DateTime.now().toLocal();
        }
      }
    }
  }

  // 为了向后兼容添加的getter
  int get patientId => patient_id;
  DateTime get followUpDate => follow_up_date;
  DateTime? get createdAt => created_at;
  DateTime? get updatedAt => updated_at;
}
