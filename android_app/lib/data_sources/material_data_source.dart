import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/material.dart';
import '../utils/datetime_formatter.dart';

// 抽象材料数据源接口
abstract class MaterialDataSource {
  Future<List<DentalMaterial>> getAllMaterials();
  Future<DentalMaterial?> getMaterialById(int id);
  Future<int> createMaterial(DentalMaterial material);
  Future<bool> updateMaterial(DentalMaterial material);
  Future<bool> deleteMaterial(int id);
  Future<List<DentalMaterial>> searchMaterials(String keyword);
  Future<Map<String, dynamic>> getMaterialStatistics();
}

// SQLite 材料数据源实现
class SqliteMaterialDataSource implements MaterialDataSource {
  final Database _database;

  SqliteMaterialDataSource(this._database);

  @override
  Future<int> createMaterial(DentalMaterial material) async {
    return await _database.insert('materials', material.toMap());
  }

  @override
  Future<bool> deleteMaterial(int id) async {
    final count = await _database.delete(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<DentalMaterial>> getAllMaterials() async {
    final result = await _database.rawQuery(
      'SELECT * FROM materials ORDER BY updated_at DESC, created_at DESC',
    );
    return result.map((e) => DentalMaterial.fromMap(e)).toList();
  }

  @override
  Future<DentalMaterial?> getMaterialById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM materials WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    return DentalMaterial.fromMap(result.first);
  }

  @override
  Future<bool> updateMaterial(DentalMaterial material) async {
    final count = await _database.update(
      'materials',
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
    return count > 0;
  }

  @override
  Future<List<DentalMaterial>> searchMaterials(String keyword) async {
    final result = await _database.rawQuery(
      'SELECT * FROM materials WHERE material_name LIKE ? OR material_code LIKE ? ORDER BY updated_at DESC, created_at DESC',
      ['%$keyword%', '%$keyword%'],
    );
    return result.map((e) => DentalMaterial.fromMap(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    final result = await _database.rawQuery('''
      SELECT COUNT(*) as total_materials, SUM(default_price) as total_value, COUNT(DISTINCT supplier) as supplier_count FROM materials
    ''');
    final row = result.isNotEmpty ? result.first : null;
    return {
      'totalMaterials': row?['total_materials'] ?? 0,
      'totalValue': (row?['total_value'] as num?)?.toDouble() ?? 0.0,
      'supplierCount': row?['supplier_count'] ?? 0,
    };
  }
}

// MySQL 材料数据源实现（使用动态连接 getter）
class MySqlMaterialDataSource implements MaterialDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlMaterialDataSource.withConnectionGetter(this._getConnection);

  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      if (field == 'created_at' || field == 'updated_at') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        try {
          final bytes = value.toBytes();
          map[field] =
              bytes.isNotEmpty ? utf8.decode(bytes, allowMalformed: true) : '';
        } catch (e) {
          map[field] = '';
        }
      } else if (value is Uint8List) {
        try {
          map[field] =
              value.isNotEmpty ? utf8.decode(value, allowMalformed: true) : '';
        } catch (e) {
          map[field] = '';
        }
      } else {
        map[field] = value;
      }
    }
    return map;
  }

  @override
  Future<int> createMaterial(DentalMaterial material) async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query(
      '''
      INSERT INTO materials (material_name, material_code, material_type, specification, unit, default_price, stock_quantity, min_stock, supplier, description, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''',
      [
        material.materialName,
        material.materialCode,
        material.materialType,
        material.specification,
        material.unit,
        material.defaultPrice,
        material.stockQuantity,
        material.minStock,
        material.supplier,
        material.description,
      ],
    );
    return results.insertId ?? 0;
  }

  @override
  Future<bool> deleteMaterial(int id) async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query('DELETE FROM materials WHERE id = ?', [
      id,
    ]);
    return (results.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<DentalMaterial>> getAllMaterials() async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query(
      'SELECT * FROM materials ORDER BY updated_at DESC, created_at DESC',
    );
    return results
        .map((row) => DentalMaterial.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<DentalMaterial?> getMaterialById(int id) async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query('SELECT * FROM materials WHERE id = ?', [
      id,
    ]);
    if (results.isEmpty) return null;
    return DentalMaterial.fromMap(_convertMySqlRow(results.first));
  }

  @override
  Future<bool> updateMaterial(DentalMaterial material) async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query(
      '''
      UPDATE materials SET material_name = ?, material_code = ?, material_type = ?, specification = ?, unit = ?, default_price = ?, stock_quantity = ?, min_stock = ?, supplier = ?, description = ?, updated_at = NOW() WHERE id = ?
    ''',
      [
        material.materialName,
        material.materialCode,
        material.materialType,
        material.specification,
        material.unit,
        material.defaultPrice,
        material.stockQuantity,
        material.minStock,
        material.supplier,
        material.description,
        material.id,
      ],
    );
    return (results.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<DentalMaterial>> searchMaterials(String keyword) async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query(
      'SELECT * FROM materials WHERE material_name LIKE ? OR material_code LIKE ? ORDER BY updated_at DESC, created_at DESC',
      ['%$keyword%', '%$keyword%'],
    );
    return results
        .map((row) => DentalMaterial.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    final conn = _getConnection();
    if (conn == null) throw Exception('MySQL连接不可用');
    final results = await conn.query(
      'SELECT COUNT(*) as total_materials, SUM(default_price) as total_value, COUNT(DISTINCT supplier) as supplier_count FROM materials',
    );
    if (results.isEmpty) {
      return {'totalMaterials': 0, 'totalValue': 0.0, 'supplierCount': 0};
    }
    final row = results.first;
    return {
      'totalMaterials': row['total_materials'] ?? 0,
      'totalValue': (row['total_value'] as num?)?.toDouble() ?? 0.0,
      'supplierCount': row['supplier_count'] ?? 0,
    };
  }
}
