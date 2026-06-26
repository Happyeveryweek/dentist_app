import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';
import '../utils/map_parser.dart';

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

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return DateTime.now();
    try {
      return DateTimeFormatter.fromDbString(value.toString());
    } catch (e) {
      LogManager.w('Material', '日期解析失败: $value');
      return DateTime.now();
    }
  }

  // 从Map创建MaterialInfo对象
  factory MaterialInfo.fromMap(Map<String, dynamic> map) {
    final p = MapParser(map, context: 'MaterialInfo');

    return MaterialInfo(
      id: p.optional('id', (v) => v as int),
      materialName: p.string('material_name'),
      materialCode: p.string('material_code'),
      materialType: p.string('material_type', defaultValue: '其他'),
      specification: p.optional('specification', (v) => v.toString()),
      unit: p.string('unit', defaultValue: '个'),
      defaultPrice: p.decimal('default_price'),
      stockQuantity: p.integer('stock_quantity'),
      minStock: p.integer('min_stock'),
      supplier: p.optional('supplier', (v) => v.toString()),
      description: p.string('description'),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
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
