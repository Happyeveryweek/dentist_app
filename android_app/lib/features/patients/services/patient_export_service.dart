import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../../../utils/database_utils.dart';

/// 患者导出和备份服务
/// 职责：患者数据导出、备份功能
class PatientExportService {
  final String _dataSourceType;

  PatientExportService(this._dataSourceType);

  /// 导出患者表
  Future<String> exportPatientsTable(String destinationDir) async {
    try {
      // 检查数据库类型，只允许导出SQLite数据库
      if (_dataSourceType != 'sqlite') {
        throw Exception('目前只支持导出SQLite数据库患者表');
      }

      print('开始导出患者表数据');

      // 使用数据库工具类导出患者表
      final exportPath = await DatabaseUtils.exportPatientsTable(
        '', // 需要数据库路径，这里需要从DatabaseProvider获取
        destinationDir,
      );

      if (exportPath.isEmpty) {
        throw Exception('导出过程中发生错误');
      }

      print('患者表已成功导出到: $exportPath');
      return exportPath;
    } catch (e) {
      print('导出患者表错误: $e');
      throw Exception('患者表导出失败: $e');
    }
  }

  /// 使用SAF保存患者数据备份
  Future<String> savePatientBackupWithSaf(
    String jsonData,
    String fileName,
  ) async {
    try {
      // 请求权限
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('需要存储权限才能备份患者数据');
      }

      // 将JSON数据写入临时文件
      final directory = await getTemporaryDirectory();
      final tempFile = File('${directory.path}/$fileName');
      await tempFile.writeAsString(jsonData);

      // 使用SAF让用户选择保存位置
      const mimeType = 'application/json';

      final params = SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: fileName,
        mimeTypesFilter: [mimeType],
      );

      final filePath = await FlutterFileDialog.saveFile(params: params);

      // 删除临时文件
      await tempFile.delete();

      if (filePath == null) {
        throw Exception('用户取消了备份操作');
      }

      return '患者数据已备份到: $filePath';
    } catch (e) {
      print('SAF备份患者数据错误: $e');
      throw Exception('备份患者数据失败：$e');
    }
  }
}
