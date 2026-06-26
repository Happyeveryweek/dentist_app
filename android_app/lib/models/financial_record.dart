import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

// 财务记录模型
class FinancialRecord {
  final int? id;
  final int patientId;
  final int totalQuantity; // 新增：收费总条数
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? patientName; // 新增：患者姓名
  // 临时字段，用于搜索，不存储到数据库
  final String? patientNamePinyin; // 患者姓名拼音
  final String? patientNameInitials; // 患者姓名拼音首字母

  const FinancialRecord({
    this.id,
    required this.patientId,
    required this.totalQuantity, // 新增：收费总条数
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.patientName, // 新增：患者姓名
    this.patientNamePinyin, // 患者姓名拼音（仅用于搜索）
    this.patientNameInitials, // 患者姓名拼音首字母（仅用于搜索）
  });

  // 从Map创建FinancialRecord
  factory FinancialRecord.fromMap(
    Map<String, dynamic> map, {
    String dataSource = 'sqlite',
  }) {
    final p = MapParser(map, context: 'FinancialRecord');
    return FinancialRecord(
      id: p.optional('id', (v) => v as int),
      patientId: p.integer('patient_id'),
      totalQuantity: p.integer('total_quantity'), // 新增：收费总条数
      notes: p.stringOptional('notes'),
      createdAt: p.dateTime('created_at'),
      updatedAt: p.dateTime('updated_at'),
      patientName: p.stringOptional('patient_name'), // 新增：患者姓名
      patientNamePinyin: p.stringOptional('patient_name_pinyin'), // 患者姓名拼音
      patientNameInitials:
          p.stringOptional('patient_name_initials'), // 患者姓名拼音首字母
    );
  }

  // 转换为Map（不包含拼音字段，因为它们不存储到数据库）
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'patient_id': patientId,
        'total_quantity': totalQuantity, // 新增：收费总条数
        'notes': notes,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
        // 注意：不包含patient_name，因为它是从JOIN查询得到的
      };
    } else {
      // SQLite数据源
      return {
        'id': id,
        'patient_id': patientId,
        'total_quantity': totalQuantity, // 新增：收费总条数
        'notes': notes,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
        // 注意：不包含patient_name，因为它是从JOIN查询得到的
      };
    }
  }

  // 复制并修改
  FinancialRecord copyWith({
    int? id,
    int? patientId,
    int? totalQuantity, // 新增：收费总条数
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? patientName, // 新增：患者姓名
    String? patientNamePinyin, // 患者姓名拼音
    String? patientNameInitials, // 患者姓名拼音首字母
  }) {
    return FinancialRecord(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      totalQuantity: totalQuantity ?? this.totalQuantity, // 新增：收费总条数
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      patientName: patientName ?? this.patientName, // 新增：患者姓名
      patientNamePinyin: patientNamePinyin ?? this.patientNamePinyin, // 患者姓名拼音
      patientNameInitials:
          patientNameInitials ?? this.patientNameInitials, // 患者姓名拼音首字母
    );
  }

  @override
  String toString() {
    return 'FinancialRecord(id: $id, patientId: $patientId, totalQuantity: $totalQuantity, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt, patientName: $patientName, patientNamePinyin: $patientNamePinyin, patientNameInitials: $patientNameInitials)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
