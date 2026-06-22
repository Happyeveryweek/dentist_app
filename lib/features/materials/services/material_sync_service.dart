import 'package:mysql1/mysql1.dart';

/// 材料同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 MaterialProvider 中提取）
class MaterialSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  MaterialSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType() == 'sqlite';

  /// 尝试将SQLite中的材料同步到MySQL（非阻塞操作）
  Future<void> syncMaterialToMySQL(
      Map<String, dynamic> materialMap, int materialId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          print('MySQL连接不可用，跳过材料同步(id=$materialId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM materials WHERE id = ? LIMIT 1',
            [materialId],
          );

          if (existResult.isNotEmpty) {
            final result = await conn.query('''
              UPDATE materials SET
                material_code = ?, material_name = ?, material_type = ?,
                specification = ?, unit = ?, unit_price = ?,
                stock_quantity = ?, min_stock = ?, supplier = ?,
                notes = ?, created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              materialMap['material_code'],
              materialMap['material_name'],
              materialMap['material_type'],
              materialMap['specification'],
              materialMap['unit'],
              materialMap['unit_price'],
              materialMap['stock_quantity'],
              materialMap['min_stock'],
              materialMap['supplier'],
              materialMap['notes'],
              materialMap['created_at'],
              materialMap['updated_at'],
              materialId,
            ]);
            print('成功更新MySQL材料(id=$materialId)，影响行数: ${result.affectedRows}');
          } else {
            final result = await conn.query('''
              INSERT INTO materials
              (id, material_code, material_name, material_type, specification, unit, unit_price, stock_quantity, min_stock, supplier, notes, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              materialId,
              materialMap['material_code'],
              materialMap['material_name'],
              materialMap['material_type'],
              materialMap['specification'],
              materialMap['unit'],
              materialMap['unit_price'],
              materialMap['stock_quantity'],
              materialMap['min_stock'],
              materialMap['supplier'],
              materialMap['notes'],
              materialMap['created_at'],
              materialMap['updated_at'],
            ]);
            print('成功将材料(id=$materialId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          print('同步材料到MySQL时出错: $e');
        }
      } catch (e) {
        print('材料同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除材料（非阻塞操作）
  Future<void> syncDeleteMaterialToMySQL(int materialId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          print('MySQL连接不可用，跳过材料删除同步(id=$materialId)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM materials WHERE id = ?',
            [materialId],
          );
          print('成功从MySQL删除材料(id=$materialId)，影响行数: ${result.affectedRows}');
        } catch (e) {
          print('从MySQL删除材料(id=$materialId)时出错: $e');
        }
      } catch (e) {
        print('材料删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }
}
