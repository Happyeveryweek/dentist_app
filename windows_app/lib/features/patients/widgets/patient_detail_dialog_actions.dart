import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/patient.dart';
import '../../../models/financial_record.dart';
import '../../../models/patient_medical_record.dart';
import '../../../providers/medical_record_provider.dart';
import '../../../widgets/success_toast.dart';
import '../../../features/financial/widgets/financial_record_edit_dialog.dart'
    show FinancialRecordEditDialog;
import '../../../utils/log_manager.dart';

/// 患者详情页弹窗打开流程收口
///
/// 把详情页里打开病历详情、预约详情、财务详情等弹窗的重复流程集中到这里。
/// 不包含数据库读取，不包含权限判断。
class PatientDetailDialogActions {
  PatientDetailDialogActions._();

  /// 显示编辑财务记录对话框
  ///
  /// 返回 true 表示用户确认编辑（有数据变更），false 表示取消或出错。
  static Future<bool> showEditFinancialRecordDialog({
    required BuildContext context,
    required Patient patient,
    required FinancialRecord record,
  }) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => FinancialRecordEditDialog(
          patient: patient,
          record: record,
        ),
      );

      return result ?? false;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('编辑财务记录失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      LogManager.e('PatientDetailDialogActions', '编辑财务记录时发生错误', error: e);
      return false;
    }
  }

  /// 显示删除财务记录确认对话框
  ///
  /// 返回 true 表示用户确认删除，false 表示取消。
  static Future<bool> showDeleteFinancialRecordConfirm({
    required BuildContext context,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '确认删除',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '确定要删除这个收费记录吗？此操作无法撤销。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// 导出病历为 PDF
  static Future<void> exportMedicalRecordToPdf({
    required BuildContext context,
    required Patient patient,
    required PatientMedicalRecord record,
  }) async {
    try {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在生成PDF...'),
            ],
          ),
        ),
      );

      final medicalRecordProvider =
          Provider.of<MedicalRecordProvider>(context, listen: false);

      // 生成PDF
      final pdfBytes = await medicalRecordProvider.exportMedicalRecordToPdf(
        patient,
        record,
        clinicName: '牙科诊所',
      );

      if (!context.mounted) return;
      // 关闭加载指示器
      Navigator.of(context).pop();

      // 使用file_picker保存文件
      final fileName =
          '病历_${patient.name}_${record.recordNumber}_${DateFormat('yyyyMMdd').format(record.recordDate)}.pdf';

      await FilePicker.platform.saveFile(
        dialogTitle: '保存病历PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (!context.mounted) return;
      AppToastManager.showSuccess(
        context,
        message: 'PDF已保存成功',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      // 关闭加载指示器（如果还在显示）
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: context.tokens.cardBackground),
              const SizedBox(width: 8),
              Expanded(child: Text('导出PDF失败: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
