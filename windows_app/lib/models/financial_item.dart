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

  // 从Map创建FinancialItem
  factory FinancialItem.fromMap(Map<String, dynamic> map) {
    return FinancialItem(
      id: map['id'] as int?,
      financialRecordId: map['financial_record_id'] as int,
      itemName: map['item_name'] as String,
      itemPrice: (map['item_price'] as num).toDouble(),
      processingFee: (map['processing_fee'] as num?)?.toDouble() ?? 0.0, // 新增：加工费
      quantity: map['quantity'] as int,
      totalPrice: (map['total_price'] as num).toDouble(),
      chargeDate: DateTimeFormatter.fromDbString(map['charge_date'] as String), // 新增：收费日期
      createdAt: DateTimeFormatter.fromDbString(map['created_at'] as String), // 新增：创建时间
      updatedAt: DateTimeFormatter.fromDbString(map['updated_at'] as String), // 新增：更新时间
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap() {
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

  // 格式化收费日期
  String get formattedChargeDate => DateFormat('yyyy-MM-dd').format(chargeDate);

  @override
  String toString() {
    return 'FinancialItem(id: $id, financialRecordId: $financialRecordId, itemName: $itemName, itemPrice: $itemPrice, processingFee: $processingFee, quantity: $quantity, totalPrice: $totalPrice, chargeDate: $chargeDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialItem &&
        other.id == id &&
        other.financialRecordId == financialRecordId &&
        other.itemName == itemName &&
        other.itemPrice == itemPrice &&
        other.processingFee == processingFee &&
        other.quantity == quantity &&
        other.totalPrice == totalPrice &&
        other.chargeDate == chargeDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        financialRecordId.hashCode ^
        itemName.hashCode ^
        itemPrice.hashCode ^
        processingFee.hashCode ^
        quantity.hashCode ^
        totalPrice.hashCode ^
        chargeDate.hashCode;
  }
}
