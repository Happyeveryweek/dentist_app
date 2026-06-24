import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';

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
    DateTime created = DateTimeFormatter.nowLocal();
    DateTime updated = DateTimeFormatter.nowLocal();
    DateTime purchaseDate = DateTimeFormatter.nowLocal();

    // 使用统一的时间解析方法，确保本地时间
    try {
      if (map['created_at'] is DateTime) {
        final dt = map['created_at'] as DateTime;
        created = dt.isUtc ? dt.toLocal() : dt;
      } else if (map['created_at'] is String) {
        created = DateTimeFormatter.fromDbString(map['created_at']);
      }
    } catch (e) {
      AppLogger.info('created_at解析失败: ${map['created_at']}, 使用当前时间');
      created = DateTimeFormatter.nowLocal();
    }

    try {
      if (map['updated_at'] is DateTime) {
        final dt = map['updated_at'] as DateTime;
        updated = dt.isUtc ? dt.toLocal() : dt;
      } else if (map['updated_at'] is String) {
        updated = DateTimeFormatter.fromDbString(map['updated_at']);
      }
    } catch (e) {
      AppLogger.info('updated_at解析失败: ${map['updated_at']}, 使用当前时间');
      updated = DateTimeFormatter.nowLocal();
    }

    try {
      if (map['purchase_date'] is DateTime) {
        final dt = map['purchase_date'] as DateTime;
        purchaseDate = dt.isUtc ? dt.toLocal() : dt;
      } else if (map['purchase_date'] is String) {
        purchaseDate = DateTimeFormatter.fromDbString(map['purchase_date']);
      }
    } catch (e) {
      AppLogger.info('purchase_date解析失败: ${map['purchase_date']}, 使用当前时间');
      purchaseDate = DateTimeFormatter.nowLocal();
    }

    return PurchaseRecord(
      id: map['id'],
      purchaseDate: purchaseDate,
      totalQuantity: map['total_quantity'] ?? 0,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      supplier: map['supplier'],
      notes: map['notes'],
      doctor: map['doctor'],
      createdAt: created,
      updatedAt: updated,
    );
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
