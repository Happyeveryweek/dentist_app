import 'package:flutter/material.dart';

import '../../../models/patient.dart';
import 'patient_form_fields.dart';

/// 同名患者浮动提示 Overlay 的构建器
/// 从 patient_form_dialog.dart 拆出，只负责 Overlay UI 构建
class ExistingPatientOverlayBuilder {
  /// 构建同名患者提示 OverlayEntry
  ///
  /// [existingPatient] - 已存在的同名患者
  /// [nameFieldKey] - 姓名输入框的 GlobalKey，用于定位
  /// [context] - BuildContext
  /// [onContinue] - 点击"继续添加"回调
  /// [onLoadExisting] - 点击"确认填充"回调
  /// [onClose] - 点击关闭按钮回调
  static OverlayEntry buildOverlayEntry({
    required Patient existingPatient,
    required GlobalKey nameFieldKey,
    required BuildContext context,
    required VoidCallback onContinue,
    required VoidCallback onLoadExisting,
    required VoidCallback onClose,
  }) {
    // 使用姓名输入框的 GlobalKey 来精确定位弹窗
    final RenderBox? nameFieldBox =
        nameFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (nameFieldBox == null) {
      // 返回一个空的 OverlayEntry，会在 insert 时被忽略
      return OverlayEntry(builder: (_) => const SizedBox.shrink());
    }

    final nameFieldPosition = nameFieldBox.localToGlobal(Offset.zero);
    final nameFieldSize = nameFieldBox.size;

    // 获取屏幕尺寸
    final screenSize = MediaQuery.of(context).size;
    const overlayWidth = 320.0;
    const overlayHeight = 280.0;

    // 计算弹窗位置，确保不超出屏幕边界
    double left = nameFieldPosition.dx;
    double top = nameFieldPosition.dy + nameFieldSize.height + 8;

    // 如果弹窗会超出右边界，向左调整
    if (left + overlayWidth > screenSize.width) {
      left = screenSize.width - overlayWidth - 16;
    }

    // 如果弹窗会超出下边界，向上显示
    if (top + overlayHeight > screenSize.height) {
      top = nameFieldPosition.dy - overlayHeight - 8;
    }

    // 确保不超出左边界和上边界
    left = left.clamp(16.0, screenSize.width - overlayWidth - 16);
    top = top.clamp(16.0, screenSize.height - overlayHeight - 16);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                _buildHeader(onClose),
                // 患者信息区域
                _buildPatientInfo(existingPatient),
                // 操作按钮
                _buildActions(onContinue, onLoadExisting),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader(VoidCallback onClose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '⚠️ 发现同名患者',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onClose,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  static Widget _buildPatientInfo(Patient existingPatient) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExistingPatientInfoRow(
              label: '病历号',
              value:
                  existingPatient.medical_record_number?.toString() ?? '无',
            ),
            ExistingPatientInfoRow(
              label: '姓名',
              value: existingPatient.name,
            ),
            ExistingPatientInfoRow(
              label: '性别',
              value: existingPatient.gender,
            ),
            ExistingPatientInfoRow(
              label: '电话',
              value: existingPatient.phone,
            ),
            if (existingPatient.address != null &&
                existingPatient.address!.isNotEmpty)
              ExistingPatientInfoRow(
                label: '地址',
                value: existingPatient.address!,
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                '请确认是否为新患者，或选择填充现有患者信息（包括材料）',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActions(
    VoidCallback onContinue,
    VoidCallback onLoadExisting,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onContinue,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                '继续添加',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onLoadExisting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 2,
              ),
              child: const Text(
                '确认填充',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
