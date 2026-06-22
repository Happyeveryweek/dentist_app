import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';

// 材料信息模型
class MaterialInfo {
  final int? id;
  final String materialName;
  final String? materialCode;
  final String materialType; // 材料类型
  final String? specification; // 规格说明
  final String unit;
  final double defaultPrice;
  final int stockQuantity; // 库存数量
  final int minStock; // 最小库存
  final String? supplier;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialInfo({
    this.id,
    required this.materialName,
    this.materialCode,
    required this.materialType, // 材料类型
    this.specification, // 规格说明
    this.unit = '个',
    this.defaultPrice = 0.0,
    this.stockQuantity = 0, // 库存数量
    this.minStock = 0, // 最小库存
    this.supplier,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 从Map创建MaterialInfo对象
  factory MaterialInfo.fromMap(Map<String, dynamic> map) {
    DateTime created = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          created = map['created_at'];
        } else {
          created = DateTimeFormatter.fromDbString(map['created_at']);
        }
      } catch (e) {
        print('解析created_at错误: ${map['created_at']}');
      }
    }

    DateTime updated = DateTime.now();
    if (map['updated_at'] != null) {
      try {
        if (map['updated_at'] is DateTime) {
          updated = map['updated_at'];
        } else {
          updated = DateTimeFormatter.fromDbString(map['updated_at']);
        }
      } catch (e) {
        print('解析updated_at错误: ${map['updated_at']}');
      }
    }

    return MaterialInfo(
      id: map['id'],
      materialName: map['material_name'] ?? '', // 使用标准字段名
      materialCode: map['material_code'] ?? '',
      materialType: map['material_type'] ?? '其他', // 使用标准字段名
      specification: map['specification'], // 规格说明
      unit: map['unit'] ?? '个',
      defaultPrice: (map['default_price'])?.toDouble() ?? 0.0, // 使用标准字段名
      stockQuantity: map['stock_quantity'] ?? 0, // 库存数量
      minStock: map['min_stock'] ?? 0, // 最小库存
      supplier: map['supplier'],
      description: map['description'] ?? '', // 使用标准字段名
      createdAt: created,
      updatedAt: updated,
    );
  }

  // 将MaterialInfo对象转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'material_name': materialName, // 使用标准字段名
      'material_code': materialCode, // 材料编码
      'material_type': materialType, // 材料类型
      'specification': specification, // 规格说明
      'unit': unit,
      'default_price': defaultPrice, // 默认价格
      'stock_quantity': stockQuantity, // 库存数量
      'min_stock': minStock, // 最小库存
      'supplier': supplier,
      'description': description, // 材料描述
      'created_at': DateTimeFormatter.toDbString(createdAt),
      'updated_at': DateTimeFormatter.toDbString(updatedAt),
    };
  }

  // 创建副本
  MaterialInfo copyWith({
    int? id,
    String? materialName,
    String? materialCode,
    String? materialType, // 材料类型
    String? specification, // 规格说明
    String? unit,
    double? defaultPrice,
    int? stockQuantity, // 库存数量
    int? minStock, // 最小库存
    String? supplier,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialInfo(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      materialCode: materialCode ?? this.materialCode,
      materialType: materialType ?? this.materialType, // 材料类型
      specification: specification ?? this.specification, // 规格说明
      unit: unit ?? this.unit,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity, // 库存数量
      minStock: minStock ?? this.minStock, // 最小库存
      supplier: supplier ?? this.supplier,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 格式化日期显示
  String get formattedCreatedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  }

  String get formattedUpdatedAt {
    return DateFormat('yyyy-MM-dd HH:mm').format(updatedAt);
  }

  // 格式化价格显示
  String get formattedPrice {
    return '¥${defaultPrice.toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'MaterialInfo(id: $id, materialName: $materialName, materialCode: $materialCode, materialType: $materialType, specification: $specification, unit: $unit, defaultPrice: $defaultPrice, stockQuantity: $stockQuantity, minStock: $minStock, supplier: $supplier, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
