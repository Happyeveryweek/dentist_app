import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: backgroundColor ?? AppTheme.cardBackground,
      elevation: elevation ?? 1,
      shape: RoundedRectangleBorder(
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppTheme.padding),
          child: child,
        ),
      ),
    );
  }
}

Future<void> saveBackupWithSaf(String sourcePath) async {
  try {
    const mimeType = 'application/octet-stream';
    final date = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final fileName = 'dental_clinic_backup_$date.db';

    final params = SaveFileDialogParams(
      sourceFilePath: sourcePath,
      fileName: fileName,
      mimeTypesFilter: [mimeType],
    );

    await FlutterFileDialog.saveFile(params: params);
    // 保存成功
  } catch (e) {
    throw Exception('备份创建失败：$e');
  }
}
