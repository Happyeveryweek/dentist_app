import 'package:mysql1/mysql1.dart';
import '../../../models/material_image.dart';
import '../../../models/patient_material.dart';
import '../../../utils/log_manager.dart';

/// 患者材料同步服务
/// 负责处理 SQLite -> MySQL 的患者材料和材料图片同步
class PatientMaterialSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  PatientMaterialSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  bool get needsSync => getEffectiveDataSourceType() == 'sqlite';

  Future<void> syncPatientMaterialToMySQL(
    PatientMaterial material,
    int materialId,
  ) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary = 'patient_id=${material.patientId}, description=${material.description}';
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'patient_material',
            action: 'upsert',
            table: 'patient_materials',
            status: 'skipped',
            recordId: materialId,
            summary: summary,
            error: 'mysql_connection_unavailable',
          );
          print('MySQL连接不可用，跳过患者材料同步(id=$materialId)');
          return;
        }

        final materialMap = material.copyWith(id: materialId).toMap();
        final exists = await conn.query(
          'SELECT id FROM patient_materials WHERE id = ? LIMIT 1',
          [materialId],
        );

        if (exists.isNotEmpty) {
          final result = await conn.query(
            '''
            UPDATE patient_materials SET
              patient_id = ?, description = ?, created_at = ?, updated_at = ?
            WHERE id = ?
            ''',
            [
              materialMap['patient_id'],
              materialMap['description'],
              materialMap['created_at'],
              materialMap['updated_at'],
              materialId,
            ],
          );
          await LogManager.logSyncOperation(
            module: 'patient_material',
            action: 'update',
            table: 'patient_materials',
            status: 'success',
            recordId: materialId,
            summary: summary,
          );
          print('成功更新MySQL患者材料(id=$materialId)，影响行数: ${result.affectedRows}');
        } else {
          final result = await conn.query(
            '''
            INSERT INTO patient_materials
            (id, patient_id, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ''',
            [
              materialId,
              materialMap['patient_id'],
              materialMap['description'],
              materialMap['created_at'],
              materialMap['updated_at'],
            ],
          );
          await LogManager.logSyncOperation(
            module: 'patient_material',
            action: 'create',
            table: 'patient_materials',
            status: 'success',
            recordId: materialId,
            summary: summary,
          );
          print('成功将患者材料(id=$materialId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'patient_material',
          action: 'upsert',
          table: 'patient_materials',
          status: 'failed',
          recordId: materialId,
          summary: 'patient_id=${material.patientId}, description=${material.description}',
          error: e.toString(),
        );
        print('同步患者材料到MySQL时出错: $e');
      }
    });
  }

  Future<void> syncDeletePatientMaterialToMySQL(int materialId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'patient_material',
            action: 'delete',
            table: 'patient_materials',
            status: 'skipped',
            recordId: materialId,
            error: 'mysql_connection_unavailable',
          );
          print('MySQL连接不可用，跳过患者材料删除同步(id=$materialId)');
          return;
        }

        await conn.query('DELETE FROM material_images WHERE material_id = ?', [materialId]);
        final result = await conn.query(
          'DELETE FROM patient_materials WHERE id = ?',
          [materialId],
        );
        await LogManager.logSyncOperation(
          module: 'patient_material',
          action: 'delete',
          table: 'patient_materials',
          status: 'success',
          recordId: materialId,
        );
        print('成功从MySQL删除患者材料(id=$materialId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'patient_material',
          action: 'delete',
          table: 'patient_materials',
          status: 'failed',
          recordId: materialId,
          error: e.toString(),
        );
        print('从MySQL删除患者材料(id=$materialId)时出错: $e');
      }
    });
  }

  Future<void> syncMaterialImageToMySQL(
    MaterialImage image,
    int imageId,
  ) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary = 'material_id=${image.materialId}, original_name=${image.originalName}';
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'material_image',
            action: 'upsert',
            table: 'material_images',
            status: 'skipped',
            recordId: imageId,
            summary: summary,
            error: 'mysql_connection_unavailable',
          );
          print('MySQL连接不可用，跳过材料图片同步(id=$imageId)');
          return;
        }

        final imageMap = image.copyWith(id: imageId).toMap();
        final exists = await conn.query(
          'SELECT id FROM material_images WHERE id = ? LIMIT 1',
          [imageId],
        );

        if (exists.isNotEmpty) {
          final result = await conn.query(
            '''
            UPDATE material_images SET
              material_id = ?, original_name = ?, image_data = ?, thumbnail_data = ?,
              image_type = ?, file_size = ?, thumbnail_size = ?, has_thumbnail = ?, image_path = ?, created_at = ?
            WHERE id = ?
            ''',
            [
              imageMap['material_id'],
              imageMap['original_name'],
              imageMap['image_data'],
              imageMap['thumbnail_data'],
              imageMap['image_type'],
              imageMap['file_size'],
              imageMap['thumbnail_size'],
              imageMap['has_thumbnail'],
              imageMap['image_path'],
              imageMap['created_at'],
              imageId,
            ],
          );
          await LogManager.logSyncOperation(
            module: 'material_image',
            action: 'update',
            table: 'material_images',
            status: 'success',
            recordId: imageId,
            summary: summary,
          );
          print('成功更新MySQL材料图片(id=$imageId)，影响行数: ${result.affectedRows}');
        } else {
          final result = await conn.query(
            '''
            INSERT INTO material_images
            (id, material_id, original_name, image_data, thumbnail_data, image_type, file_size, thumbnail_size, has_thumbnail, image_path, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              imageId,
              imageMap['material_id'],
              imageMap['original_name'],
              imageMap['image_data'],
              imageMap['thumbnail_data'],
              imageMap['image_type'],
              imageMap['file_size'],
              imageMap['thumbnail_size'],
              imageMap['has_thumbnail'],
              imageMap['image_path'],
              imageMap['created_at'],
            ],
          );
          await LogManager.logSyncOperation(
            module: 'material_image',
            action: 'create',
            table: 'material_images',
            status: 'success',
            recordId: imageId,
            summary: summary,
          );
          print('成功将材料图片(id=$imageId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'material_image',
          action: 'upsert',
          table: 'material_images',
          status: 'failed',
          recordId: imageId,
          summary: 'material_id=${image.materialId}, original_name=${image.originalName}',
          error: e.toString(),
        );
        print('同步材料图片到MySQL时出错: $e');
      }
    });
  }

  Future<void> syncDeleteMaterialImageToMySQL(int imageId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'material_image',
            action: 'delete',
            table: 'material_images',
            status: 'skipped',
            recordId: imageId,
            error: 'mysql_connection_unavailable',
          );
          print('MySQL连接不可用，跳过材料图片删除同步(id=$imageId)');
          return;
        }

        final result = await conn.query(
          'DELETE FROM material_images WHERE id = ?',
          [imageId],
        );
        await LogManager.logSyncOperation(
          module: 'material_image',
          action: 'delete',
          table: 'material_images',
          status: 'success',
          recordId: imageId,
        );
        print('成功从MySQL删除材料图片(id=$imageId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'material_image',
          action: 'delete',
          table: 'material_images',
          status: 'failed',
          recordId: imageId,
          error: e.toString(),
        );
        print('从MySQL删除材料图片(id=$imageId)时出错: $e');
      }
    });
  }
}
