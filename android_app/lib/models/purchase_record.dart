import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

// 采购记录模型
class PurchaseRecord {
  final int? id;
  final DateTime purchaseDate;
  final int totalQuantity;
  final double totalAmount;
  final String? supplier;
  final String? notes;
  final String? doctor;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseRecord({
    this.id,
    required this.purchaseDate,
    required this.totalQuantity,
    required this.totalAmount,
    this.supplier,
    this.notes,
    this.doctor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTimeFormatter.nowLocal(),
       updatedAt = updatedAt ?? DateTimeFormatter.nowLocal();

  // 从Map构造PurchaseRecord对象
  factory PurchaseRecord.fromMap(
    Map<String, dynamic> map, {
    String dataSource = 'sqlite',
  }) {
    final p = MapParser(map, context: 'PurchaseRecord');
    return PurchaseRecord(
      id: p.optional('id', (v) => v as int),
      purchaseDate: _toLocalDateTime(p.dateTime('purchase_date')),
      totalQuantity: p.integer('total_quantity'),
      totalAmount: p.doubleValue('total_amount'),
      supplier: p.stringOptional('supplier'),
      notes: p.stringOptional('notes'),
      doctor: p.stringOptional('doctor'),
      createdAt: _toLocalDateTime(p.dateTime('created_at')),
      updatedAt: _toLocalDateTime(p.dateTime('updated_at')),
    );
  }

  // 辅助方法：将DateTime转换为本地时间
  static DateTime _toLocalDateTime(DateTime dt) {
    return dt.isUtc ? dt.toLocal() : dt;
  }

  // 将PurchaseRecord对象转换为Map
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'purchase_date': DateTimeFormatter.toDbString(purchaseDate),
        'total_quantity': totalQuantity,
        'total_amount': totalAmount,
        'supplier': supplier,
        'notes': notes,
        'doctor': doctor,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    } else {
      // SQLite数据源
      return {
        'id': id,
        'purchase_date': DateTimeFormatter.toDbString(purchaseDate),
        'total_quantity': totalQuantity,
        'total_amount': totalAmount,
        'supplier': supplier,
        'notes': notes,
        'doctor': doctor,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    }
  }

  // 创建副本
  PurchaseRecord copyWith({
    int? id,
    DateTime? purchaseDate,
    int? totalQuantity,
    double? totalAmount,
    String? supplier,
    String? notes,
    String? doctor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseRecord(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalAmount: totalAmount ?? this.totalAmount,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      doctor: doctor ?? this.doctor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTimeFormatter.nowLocal(),
    );
  }

  @override
  String toString() {
    return 'PurchaseRecord(id: $id, purchaseDate: $purchaseDate, totalQuantity: $totalQuantity, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
