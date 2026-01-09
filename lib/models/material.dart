import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';

// 材料信息模型
class DentalMaterial {
  final int? id;
  final String materialName;
  final String? materialCode;
  final String materialType; // 新增：材料类型
  final String? specification; // 新增：规格说明
  final String unit;
  final double defaultPrice;
  final int stockQuantity; // 新增：库存数量
  final int minStock; // 新增：最小库存
  final String? supplier;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  DentalMaterial({
    this.id,
    required this.materialName,
    this.materialCode,
    this.materialType = '其他',
    this.specification,
    this.unit = '个',
    this.defaultPrice = 0.0,
    this.stockQuantity = 0,
    this.minStock = 0,
    this.supplier,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 从Map构造DentalMaterial对象
  factory DentalMaterial.fromMap(Map<String, dynamic> map, {String dataSource = 'sqlite'}) {
    DateTime created = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          created = map['created_at'];
        } else if (map['created_at'] is String) {
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
        } else if (map['updated_at'] is String) {
          updated = DateTimeFormatter.fromDbString(map['updated_at']);
        }
      } catch (e) {
        print('解析updated_at错误: ${map['updated_at']}');
      }
    }

    // 根据数据源适配字段映射
    if (dataSource == 'mysql') {
      return DentalMaterial(
        id: map['id'],
        materialName: map['material_name'] ?? '',
        materialCode: map['material_code'],
        materialType: map['material_type'] ?? '其他',
        specification: map['specification'],
        unit: map['unit'] ?? '个',
        defaultPrice: (map['default_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: map['stock_quantity'] ?? 0,
        minStock: map['min_stock'] ?? 0,
        supplier: map['supplier'],
        description: map['description'],
        createdAt: created,
        updatedAt: updated,
      );
    } else {
      // SQLite数据源
      return DentalMaterial(
        id: map['id'],
        materialName: map['material_name'] ?? '',
        materialCode: map['material_code'],
        materialType: map['material_type'] ?? '其他',
        specification: map['specification'],
        unit: map['unit'] ?? '个',
        defaultPrice: (map['default_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: map['stock_quantity'] ?? 0,
        minStock: map['min_stock'] ?? 0,
        supplier: map['supplier'],
        description: map['description'],
        createdAt: created,
        updatedAt: updated,
      );
    }
  }

  // 将Material对象转换为Map
  Map<String, dynamic> toMap({String dataSource = 'sqlite'}) {
    if (dataSource == 'mysql') {
      return {
        'id': id,
        'material_name': materialName,
        'material_code': materialCode,
        'material_type': materialType,
        'specification': specification,
        'unit': unit,
        'default_price': defaultPrice,
        'stock_quantity': stockQuantity,
        'min_stock': minStock,
        'supplier': supplier,
        'description': description,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    } else {
      // SQLite数据源
      return {
        'id': id,
        'material_name': materialName,
        'material_code': materialCode,
        'material_type': materialType,
        'specification': specification,
        'unit': unit,
        'default_price': defaultPrice,
        'stock_quantity': stockQuantity,
        'min_stock': minStock,
        'supplier': supplier,
        'description': description,
        'created_at': DateTimeFormatter.toDbString(createdAt),
        'updated_at': DateTimeFormatter.toDbString(updatedAt),
      };
    }
  }

  // 创建副本
  DentalMaterial copyWith({
    int? id,
    String? materialName,
    String? materialCode,
    String? materialType,
    String? specification,
    String? unit,
    double? defaultPrice,
    int? stockQuantity,
    int? minStock,
    String? supplier,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DentalMaterial(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      materialCode: materialCode ?? this.materialCode,
      materialType: materialType ?? this.materialType,
      specification: specification ?? this.specification,
      unit: unit ?? this.unit,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minStock: minStock ?? this.minStock,
      supplier: supplier ?? this.supplier,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'DentalMaterial(id: $id, materialName: $materialName, materialType: $materialType, unit: $unit, defaultPrice: $defaultPrice, stockQuantity: $stockQuantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DentalMaterial && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
