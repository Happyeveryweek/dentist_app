import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';

// 采购项目明细模型
class PurchaseItem {
  final int? id;
  final int purchaseRecordId;
  final int? materialId; // 可为空，支持自定义材料（关联到MaterialInfo）
  final String materialName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? unit; // 材料单位
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseItem({
    this.id,
    required this.purchaseRecordId,
    this.materialId,
    required this.materialName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.unit, // 材料单位
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTimeFormatter.nowLocal(),
       updatedAt = updatedAt ?? DateTimeFormatter.nowLocal();

  // 从Map构造PurchaseItem对象
  factory PurchaseItem.fromMap(Map<String, dynamic> map, {String dataSource = 'sqlite'}) {
    DateTime created = _parseDateTimeFlexible(map['created_at']);
    DateTime updated = _parseDateTimeFlexible(map['updated_at']);

    return PurchaseItem(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0'),
      purchaseRecordId: map['purchase_record_id'] is int ? map['purchase_record_id'] : int.tryParse(map['purchase_record_id']?.toString() ?? '0'),
      materialId: map['material_id'] != null ? (map['material_id'] is int ? map['material_id'] : int.tryParse(map['material_id']?.toString() ?? '0')) : null,
      materialName: map['material_name']?.toString() ?? '',
      quantity: map['quantity'] is int ? map['quantity'] : int.tryParse(map['quantity']?.toString() ?? '0'),
      unitPrice: map['unit_price'] is double ? map['unit_price'] : double.tryParse(map['unit_price']?.toString() ?? '0.0'),
      totalPrice: map['total_price'] is double ? map['total_price'] : double.tryParse(map['total_price']?.toString() ?? '0.0'),
      unit: map['unit']?.toString(), // 材料单位
      createdAt: created,
      updatedAt: updated,
    );
  }

  // 使用统一的时间解析方法，确保本地时间
  static DateTime _parseDateTimeFlexible(dynamic value) {
    if (value == null) return DateTimeFormatter.nowLocal();
    try {
      if (value is DateTime) {
        final dt = value as DateTime;
        return dt.isUtc ? dt.toLocal() : dt;
      }
      final s = value.toString();
      // 先尝试 ISO8601 解析（支持带 T、微秒）
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return dt.isUtc ? dt.toLocal() : dt;
      }

      // 回退到统一的数据库格式解析
      try {
        return DateTimeFormatter.fromDbString(s);
      } catch (_) {
        // 最后回退到当前时间
        print('PurchaseItem._parseDateTimeFlexible: 无法解析时间字符串: $s, 使用当前时间');
        return DateTimeFormatter.nowLocal();
      }
    } catch (e) {
      print('PurchaseItem._parseDateTimeFlexible 异常: $e');
      return DateTimeFormatter.nowLocal();
    }
  }

  // 将PurchaseItem对象转换为Map
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'purchase_record_id': purchaseRecordId,
        'material_id': materialId,
        'material_name': materialName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'unit': unit, // 材料单位
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    } else {
      // SQLite数据源
      return {
        'id': id,
        'purchase_record_id': purchaseRecordId,
        'material_id': materialId,
        'material_name': materialName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'unit': unit, // 材料单位
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    }
  }

  // 创建副本
  PurchaseItem copyWith({
    int? id,
    int? purchaseRecordId,
    int? materialId,
    String? materialName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      purchaseRecordId: purchaseRecordId ?? this.purchaseRecordId,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTimeFormatter.nowLocal(),
    );
  }

  // 计算总价
  double calculateTotalPrice() {
    return unitPrice * quantity;
  }

  @override
  String toString() {
    return 'PurchaseItem(id: $id, materialName: $materialName, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
