import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';

// 采购记录模型
class PurchaseRecord {
  final int? id;
  final DateTime purchaseDate;
  final int totalQuantity;
  final double totalAmount;
  final String? supplier;
  final String? doctor;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseRecord({
    this.id,
    required this.purchaseDate,
    required this.totalQuantity,
    required this.totalAmount,
    this.supplier,
    this.doctor,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 从Map构造PurchaseRecord对象
  factory PurchaseRecord.fromMap(Map<String, dynamic> map) {
    DateTime created = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          created = map['created_at'];
        } else {
          created =
              DateTimeFormatter.fromDbString(map['created_at'].toString());
        }
      } catch (e) {
        LogManager.e('PurchaseRecord', '解析created_at错误: ${map['created_at']}');
      }
    }

    DateTime updated = DateTime.now();
    if (map['updated_at'] != null) {
      try {
        if (map['updated_at'] is DateTime) {
          updated = map['updated_at'];
        } else {
          updated =
              DateTimeFormatter.fromDbString(map['updated_at'].toString());
        }
      } catch (e) {
        LogManager.e('PurchaseRecord', '解析updated_at错误: ${map['updated_at']}');
      }
    }

    DateTime purchaseDate = DateTime.now();
    if (map['purchase_date'] != null) {
      try {
        if (map['purchase_date'] is DateTime) {
          purchaseDate = map['purchase_date'];
        } else {
          purchaseDate =
              DateTimeFormatter.fromDbString(map['purchase_date'].toString());
        }
      } catch (e) {
        LogManager.e(
            'PurchaseRecord', '解析purchase_date错误: ${map['purchase_date']}');
      }
    }

    return PurchaseRecord(
      id: _parseIntOrNull(map['id']),
      purchaseDate: purchaseDate,
      totalQuantity: _parseInt(map['total_quantity']),
      totalAmount: _parseDouble(map['total_amount']),
      supplier: _parseStringOrNull(map['supplier']),
      doctor: _parseStringOrNull(map['doctor']),
      notes: _parseStringOrNull(map['notes']),
      createdAt: created,
      updatedAt: updated,
    );
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static int? _parseIntOrNull(dynamic value) {
    if (value == null) return null;
    return _parseInt(value);
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static String? _parseStringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  // 将PurchaseRecord对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_date': DateTimeFormatter.toDbString(purchaseDate),
      'total_quantity': totalQuantity,
      'total_amount': totalAmount,
      'supplier': supplier,
      'doctor': doctor,
      'notes': notes,
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 创建副本
  PurchaseRecord copyWith({
    int? id,
    DateTime? purchaseDate,
    int? totalQuantity,
    double? totalAmount,
    String? supplier,
    String? doctor,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseRecord(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalAmount: totalAmount ?? this.totalAmount,
      supplier: supplier ?? this.supplier,
      doctor: doctor ?? this.doctor,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 格式化日期显示
  String get formattedPurchaseDate {
    return DateFormat('yyyy-MM-dd').format(purchaseDate);
  }

  String get formattedCreatedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  }

  String get formattedUpdatedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(updatedAt);
  }

  // 格式化金额显示
  String get formattedTotalAmount {
    return '¥${totalAmount.toStringAsFixed(2)}';
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
