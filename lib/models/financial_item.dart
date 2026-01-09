import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';

// 收费项目明细模型
class FinancialItem {
  final int? id;
  final int financialRecordId;
  final String itemName;
  final double itemPrice;
  final double processingFee; // 新增：加工费
  final int quantity;
  final double totalPrice;
  final DateTime chargeDate; // 新增：收费日期
  final DateTime createdAt; // 新增：创建时间
  final DateTime updatedAt; // 新增：更新时间

  const FinancialItem({
    this.id,
    required this.financialRecordId,
    required this.itemName,
    required this.itemPrice,
    required this.processingFee, // 新增：加工费
    required this.quantity,
    required this.totalPrice,
    required this.chargeDate, // 新增：收费日期
    required this.createdAt, // 新增：创建时间
    required this.updatedAt, // 新增：更新时间
  });

  // 辅助方法：安全解析日期 - 使用统一格式
  static DateTime _parseDateTime(dynamic value, String fieldName) {
    if (value == null) return DateTime.now();
    
    if (value is DateTime) {
      return value;
    }
    
    if (value is String) {
      return DateTimeFormatter.fromDbString(value);
    }
    
    return DateTime.now();
  }

  // 从Map创建FinancialItem
  factory FinancialItem.fromMap(Map<String, dynamic> map, {String dataSource = 'sqlite'}) {
    DateTime chargeDate = _parseDateTime(map['charge_date'], 'charge_date');
    DateTime created = _parseDateTime(map['created_at'], 'created_at');
    DateTime updated = _parseDateTime(map['updated_at'], 'updated_at');

    return FinancialItem(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      financialRecordId: map['financial_record_id'] != null ? int.tryParse(map['financial_record_id'].toString()) ?? 0 : 0,
      itemName: map['item_name']?.toString() ?? '',
      itemPrice: map['item_price'] != null ? (map['item_price'] is double ? map['item_price'] : double.tryParse(map['item_price'].toString()) ?? 0.0) : 0.0,
      processingFee: map['processing_fee'] != null ? (map['processing_fee'] is double ? map['processing_fee'] : double.tryParse(map['processing_fee'].toString()) ?? 0.0) : 0.0,
      quantity: map['quantity'] != null ? int.tryParse(map['quantity'].toString()) ?? 0 : 0,
      totalPrice: map['total_price'] != null ? (map['total_price'] is double ? map['total_price'] : double.tryParse(map['total_price'].toString()) ?? 0.0) : 0.0,
      chargeDate: chargeDate, // 新增：收费日期
      createdAt: created, // 新增：创建时间
      updatedAt: updated, // 新增：更新时间
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'financial_record_id': financialRecordId,
        'item_name': itemName,
        'item_price': itemPrice,
        'processing_fee': processingFee, // 新增：加工费
        'quantity': quantity,
        'total_price': totalPrice,
        'charge_date': DateTimeFormatter.toDbString(chargeDate), // 新增：收费日期
        'created_at': DateTimeFormatter.toDbString(createdAt), // 新增：创建时间
        'updated_at': DateTimeFormatter.toDbString(updatedAt), // 新增：更新时间
      };
    } else {
      // SQLite数据源
      return {
        'id': id,
        'financial_record_id': financialRecordId,
        'item_name': itemName,
        'item_price': itemPrice,
        'processing_fee': processingFee, // 新增：加工费
        'quantity': quantity,
        'total_price': totalPrice,
        'charge_date': DateTimeFormatter.toDbString(chargeDate), // 新增：收费日期
        'created_at': DateTimeFormatter.toDbString(createdAt), // 新增：创建时间
        'updated_at': DateTimeFormatter.toDbString(updatedAt), // 新增：更新时间
      };
    }
  }

  // 复制并修改
  FinancialItem copyWith({
    int? id,
    int? financialRecordId,
    String? itemName,
    double? itemPrice,
    double? processingFee, // 新增：加工费
    int? quantity,
    double? totalPrice,
    DateTime? chargeDate, // 新增：收费日期
    DateTime? createdAt, // 新增：创建时间
    DateTime? updatedAt, // 新增：更新时间
  }) {
    return FinancialItem(
      id: id ?? this.id,
      financialRecordId: financialRecordId ?? this.financialRecordId,
      itemName: itemName ?? this.itemName,
      itemPrice: itemPrice ?? this.itemPrice,
      processingFee: processingFee ?? this.processingFee, // 新增：加工费
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      chargeDate: chargeDate ?? this.chargeDate, // 新增：收费日期
      createdAt: createdAt ?? this.createdAt, // 新增：创建时间
      updatedAt: updatedAt ?? this.updatedAt, // 新增：更新时间
    );
  }

  // 计算总价
  double calculateTotalPrice() {
    return (itemPrice + processingFee) * quantity;
  }

  @override
  String toString() {
    return 'FinancialItem(id: $id, itemName: $itemName, quantity: $quantity, totalPrice: $totalPrice, processingFee: $processingFee, chargeDate: $chargeDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}