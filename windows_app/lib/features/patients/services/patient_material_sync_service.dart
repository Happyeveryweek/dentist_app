import 'package:mysql1/mysql1.dart';
import 'patient_sync_log_helper.dart';
import '../../../models/material_image.dart';
import '../../../models/patient_material.dart';
import '../../../models/patient_sync_log.dart';
import '../../../utils/log_manager.dart';
import '../../../models/data_source.dart';

/// 患者材料同步服务
/// 负责处理 SQLite -> MySQL 的患者材料和材料图片同步
class PatientMaterialSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  PatientMaterialSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  bool get needsSync => getEffectiveDataSourceType().isSqliteDataSource;

  Future<void> syncPatientMaterialToMySQL(
    PatientMaterial material,
    int materialId,
  ) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary =
            'patient_id=${material.patientId}, description=${material.description}';
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
          await _addPatientSyncLog(
            entityType: 'patient_material',
            entityName: '患者材料',
            action: 'upsert',
            status: 'skipped',
            patientId: material.patientId,
            recordId: materialId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w('PatientMaterialSyncService',
              'MySQL连接不可用，跳过患者材料同步(id=$materialId)');
          return;
        }

        final materialMap = material.copyWith(id: materialId).toMap();
        final exists = await conn.query(
          'SELECT * FROM patient_materials WHERE id = ? LIMIT 1',
          [materialId],
        );

        if (exists.isNotEmpty) {
          final fieldChanges = PatientSyncLogHelper.buildFieldChanges(
            oldValues: exists.first.fields,
            newValues: materialMap,
            fields: _patientMaterialSyncFields,
          );
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
          await _addPatientSyncLog(
            entityType: 'patient_material',
            entityName: '患者材料',
            action: 'update',
            status: 'success',
            patientId: material.patientId,
            recordId: materialId,
            fieldChanges: fieldChanges,
          );
          LogManager.i('PatientMaterialSyncService',
              '成功更新MySQL患者材料(id=$materialId)，影响行数: ${result.affectedRows}');
        } else {
          final fieldChanges = PatientSyncLogHelper.buildCreateChanges(
              materialMap, _patientMaterialSyncFields);
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
          await _addPatientSyncLog(
            entityType: 'patient_material',
            entityName: '患者材料',
            action: 'create',
            status: 'success',
            patientId: material.patientId,
            recordId: materialId,
            fieldChanges: fieldChanges,
          );
          LogManager.i('PatientMaterialSyncService',
              '成功将患者材料(id=$materialId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'patient_material',
          action: 'upsert',
          table: 'patient_materials',
          status: 'failed',
          recordId: materialId,
          summary:
              'patient_id=${material.patientId}, description=${material.description}',
          error: e.toString(),
        );
        await _addPatientSyncLog(
          entityType: 'patient_material',
          entityName: '患者材料',
          action: 'upsert',
          status: 'failed',
          patientId: material.patientId,
          recordId: materialId,
          error: e.toString(),
        );
        LogManager.e('PatientMaterialSyncService', '同步患者材料到MySQL时出错', error: e);
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
          await _addPatientSyncLog(
            entityType: 'patient_material',
            entityName: '患者材料',
            action: 'delete',
            status: 'skipped',
            recordId: materialId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w('PatientMaterialSyncService',
              'MySQL连接不可用，跳过患者材料删除同步(id=$materialId)');
          return;
        }

        final existing = await conn.query(
          'SELECT patient_id FROM patient_materials WHERE id = ? LIMIT 1',
          [materialId],
        );
        final patientId = existing.isNotEmpty
            ? _intValue(existing.first['patient_id'])
            : null;
        await conn.query(
            'DELETE FROM material_images WHERE material_id = ?', [materialId]);
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
        await _addPatientSyncLog(
          entityType: 'patient_material',
          entityName: '患者材料',
          action: 'delete',
          status: 'success',
          patientId: patientId,
          recordId: materialId,
        );
        LogManager.i('PatientMaterialSyncService',
            '成功从MySQL删除患者材料(id=$materialId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'patient_material',
          action: 'delete',
          table: 'patient_materials',
          status: 'failed',
          recordId: materialId,
          error: e.toString(),
        );
        await _addPatientSyncLog(
          entityType: 'patient_material',
          entityName: '患者材料',
          action: 'delete',
          status: 'failed',
          recordId: materialId,
          error: e.toString(),
        );
        LogManager.e(
            'PatientMaterialSyncService', '从MySQL删除患者材料(id=$materialId)时出错',
            error: e);
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
        final summary =
            'material_id=${image.materialId}, original_name=${image.originalName}';
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
          await _addPatientSyncLog(
            entityType: 'material_image',
            entityName: '材料图片',
            action: 'upsert',
            status: 'skipped',
            recordId: imageId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'PatientMaterialSyncService', 'MySQL连接不可用，跳过材料图片同步(id=$imageId)');
          return;
        }

        final imageMap = image.copyWith(id: imageId).toMap();
        final exists = await conn.query(
          '''
          SELECT mi.*, pm.patient_id
          FROM material_images mi
          LEFT JOIN patient_materials pm ON pm.id = mi.material_id
          WHERE mi.id = ?
          LIMIT 1
          ''',
          [imageId],
        );

        if (exists.isNotEmpty) {
          final fieldChanges = PatientSyncLogHelper.buildFieldChanges(
            oldValues: exists.first.fields,
            newValues: imageMap,
            fields: _materialImageSyncFields,
          );
          final patientId = _intValue(exists.first['patient_id']);
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
          await _addPatientSyncLog(
            entityType: 'material_image',
            entityName: '材料图片',
            action: 'update',
            status: 'success',
            patientId: patientId,
            recordId: imageId,
            fieldChanges: fieldChanges,
          );
          LogManager.i('PatientMaterialSyncService',
              '成功更新MySQL材料图片(id=$imageId)，影响行数: ${result.affectedRows}');
        } else {
          final fieldChanges = PatientSyncLogHelper.buildCreateChanges(
              imageMap, _materialImageSyncFields);
          final patientId = await _getPatientIdByMaterialId(
            conn,
            image.materialId,
          );
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
          await _addPatientSyncLog(
            entityType: 'material_image',
            entityName: '材料图片',
            action: 'create',
            status: 'success',
            patientId: patientId,
            recordId: imageId,
            fieldChanges: fieldChanges,
          );
          LogManager.i('PatientMaterialSyncService',
              '成功将材料图片(id=$imageId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'material_image',
          action: 'upsert',
          table: 'material_images',
          status: 'failed',
          recordId: imageId,
          summary:
              'material_id=${image.materialId}, original_name=${image.originalName}',
          error: e.toString(),
        );
        await _addPatientSyncLog(
          entityType: 'material_image',
          entityName: '材料图片',
          action: 'upsert',
          status: 'failed',
          recordId: imageId,
          error: e.toString(),
        );
        LogManager.e('PatientMaterialSyncService', '同步材料图片到MySQL时出错', error: e);
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
          await _addPatientSyncLog(
            entityType: 'material_image',
            entityName: '材料图片',
            action: 'delete',
            status: 'skipped',
            recordId: imageId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w('PatientMaterialSyncService',
              'MySQL连接不可用，跳过材料图片删除同步(id=$imageId)');
          return;
        }

        final existing = await conn.query(
          '''
          SELECT pm.patient_id
          FROM material_images mi
          LEFT JOIN patient_materials pm ON pm.id = mi.material_id
          WHERE mi.id = ?
          LIMIT 1
          ''',
          [imageId],
        );
        final patientId = existing.isNotEmpty
            ? _intValue(existing.first['patient_id'])
            : null;
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
        await _addPatientSyncLog(
          entityType: 'material_image',
          entityName: '材料图片',
          action: 'delete',
          status: 'success',
          patientId: patientId,
          recordId: imageId,
        );
        LogManager.i('PatientMaterialSyncService',
            '成功从MySQL删除材料图片(id=$imageId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'material_image',
          action: 'delete',
          table: 'material_images',
          status: 'failed',
          recordId: imageId,
          error: e.toString(),
        );
        await _addPatientSyncLog(
          entityType: 'material_image',
          entityName: '材料图片',
          action: 'delete',
          status: 'failed',
          recordId: imageId,
          error: e.toString(),
        );
        LogManager.e(
            'PatientMaterialSyncService', '从MySQL删除材料图片(id=$imageId)时出错',
            error: e);
      }
    });
  }

  Future<void> _addPatientSyncLog({
    required String entityType,
    required String entityName,
    required String action,
    required String status,
    int? patientId,
    int? recordId,
    List<PatientSyncFieldChange> fieldChanges = const [],
    String? error,
  }) {
    return PatientSyncLog.addLog(
      PatientSyncLog(
        syncTime: DateTime.now(),
        entityType: entityType,
        entityName: entityName,
        action: action,
        status: status,
        patientId: patientId,
        recordId: recordId,
        fieldChanges: fieldChanges,
        errorMessage: error,
      ),
    );
  }

  Future<int?> _getPatientIdByMaterialId(
    MySqlConnection conn,
    int materialId,
  ) async {
    final result = await conn.query(
      'SELECT patient_id FROM patient_materials WHERE id = ? LIMIT 1',
      [materialId],
    );
    if (result.isEmpty) return null;
    return _intValue(result.first['patient_id']);
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value.toString());
  }

  static const Map<String, String> _patientMaterialSyncFields = {
    'patient_id': '患者ID',
    'description': '材料描述',
  };

  static const Map<String, String> _materialImageSyncFields = {
    'material_id': '材料ID',
    'original_name': '文件名',
    'image_type': '图片类型',
    'file_size': '文件大小',
    'thumbnail_size': '缩略图大小',
    'has_thumbnail': '是否有缩略图',
    'image_path': '图片路径',
  };
}
