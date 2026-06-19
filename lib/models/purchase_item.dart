// 采购项目明细模型
import '../utils/datetime_formatter.dart';
class PurchaseItem {
  final int? id;
  final int purchaseRecordId;
  final int? materialId; // 可为空，支持自定义材料（关联到MaterialInfo）
  final String materialName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? unit; // 新增：材料单位
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
    this.unit, // 新增：材料单位
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // 从Map构造PurchaseItem对象
  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      purchaseRecordId: map['purchase_record_id'],
      materialId: map['material_id'],
      materialName: map['material_name'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: map['unit_price']?.toDouble() ?? 0.0,
      totalPrice: map['total_price']?.toDouble() ?? 0.0,
      unit: map['unit'], // 新增：材料单位
      // 如果数据库中没有时间字符串字段，使用当前时间
      createdAt: _parseDateTimeFlexible(map['created_at']),
      updatedAt: _parseDateTimeFlexible(map['updated_at']),
    );
  }

  // 统一使用DateTimeFormatter处理时间格式
  static DateTime _parseDateTimeFlexible(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    try {
      return DateTimeFormatter.fromDbString(value.toString());
    } catch (e) {
      // 解析失败时使用当前时间
      return DateTime.now();
    }
  }

  // 将PurchaseItem对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_record_id': purchaseRecordId,
      'material_id': materialId,
      'material_name': materialName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'unit': unit, // 新增：材料单位
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
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
    String? unit, // 新增：材料单位
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
      unit: unit ?? this.unit, // 新增：材料单位
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 计算总价
  double calculateTotalPrice() {
    return unitPrice * quantity;
  }

  // 格式化单价显示
  String get formattedUnitPrice {
    return '¥${unitPrice.toStringAsFixed(2)}';
  }

  // 格式化总价显示
  String get formattedTotalPrice {
    return '¥${totalPrice.toStringAsFixed(2)}';
  }

  // 格式化单位显示
  String get formattedUnit {
    return unit ?? '个';
  }

  @override
  String toString() {
    return 'PurchaseItem(id: $id, materialName: $materialName, quantity: $quantity, unit: $unit, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}