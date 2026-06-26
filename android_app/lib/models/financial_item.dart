import '../utils/datetime_formatter.dart';
import '../utils/map_parser.dart';

// 收费项目明细模型
class FinancialItem {
  final int? id;
  final int financialRecordId;
  final String itemName;
  final String? paymentMethod;
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
    this.paymentMethod,
    required this.itemPrice,
    required this.processingFee, // 新增：加工费
    required this.quantity,
    required this.totalPrice,
    required this.chargeDate, // 新增：收费日期
    required this.createdAt, // 新增：创建时间
    required this.updatedAt, // 新增：更新时间
  });

  // 从Map创建FinancialItem
  factory FinancialItem.fromMap(
    Map<String, dynamic> map, {
    String dataSource = 'sqlite',
  }) {
    final p = MapParser(map, context: 'FinancialItem');
    return FinancialItem(
      id: p.optional('id', (v) => v as int),
      financialRecordId: p.integer('financial_record_id'),
      itemName: p.string('item_name'),
      paymentMethod: p.stringOptional('payment_method'),
      itemPrice: p.doubleValue('item_price'),
      processingFee: p.doubleValue('processing_fee'),
      quantity: p.integer('quantity'),
      totalPrice: p.doubleValue('total_price'),
      chargeDate: p.dateTime('charge_date'), // 新增：收费日期
      createdAt: p.dateTime('created_at'), // 新增：创建时间
      updatedAt: p.dateTime('updated_at'), // 新增：更新时间
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'financial_record_id': financialRecordId,
        'item_name': itemName,
        'payment_method': paymentMethod,
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
        'payment_method': paymentMethod,
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
    String? paymentMethod,
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
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
    return 'FinancialItem(id: $id, itemName: $itemName, paymentMethod: $paymentMethod, quantity: $quantity, totalPrice: $totalPrice, processingFee: $processingFee, chargeDate: $chargeDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinancialItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
