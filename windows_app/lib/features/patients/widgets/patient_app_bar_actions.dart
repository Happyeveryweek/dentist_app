import 'package:flutter/material.dart';

import '../../../widgets/dental_icons.dart';

class PatientAppBarActions extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onAddPatient;
  final VoidCallback onShowStatistics;
  final Future<void> Function() onRefresh;

  const PatientAppBarActions({
    Key? key,
    required this.onExport,
    required this.onAddPatient,
    required this.onShowStatistics,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PatientAppBarActionButton(
          margin: const EdgeInsets.only(right: 8),
          backgroundColor: DentalColors.success.withValues(alpha: 0.1),
          borderColor: DentalColors.success.withValues(alpha: 0.3),
          icon: Icons.file_download_rounded,
          iconColor: DentalColors.success,
          tooltip: '导出患者数据',
          onPressed: onExport,
        ),
        _PatientAppBarActionButton(
          margin: const EdgeInsets.only(right: 8),
          gradient: DentalColors.primaryGradient,
          icon: Icons.add_rounded,
          iconColor: Colors.white,
          tooltip: '添加患者',
          onPressed: onAddPatient,
        ),
        _PatientAppBarActionButton(
          margin: const EdgeInsets.only(right: 8),
          backgroundColor: Colors.purple.withValues(alpha: 0.1),
          borderColor: Colors.purple.withValues(alpha: 0.3),
          icon: Icons.bar_chart_rounded,
          iconColor: Colors.purple,
          tooltip: '患者统计图表',
          onPressed: onShowStatistics,
        ),
        _PatientAppBarActionButton(
          margin: const EdgeInsets.only(right: 16),
          backgroundColor: DentalColors.info.withValues(alpha: 0.1),
          borderColor: DentalColors.info.withValues(alpha: 0.3),
          icon: Icons.refresh_rounded,
          iconColor: DentalColors.info,
          tooltip: '刷新数据',
          onPressed: () {
            onRefresh();
          },
        ),
      ],
    );
  }
}

class _PatientAppBarActionButton extends StatelessWidget {
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final Gradient? gradient;
  final IconData icon;
  final Color iconColor;
  final String tooltip;
  final VoidCallback onPressed;

  const _PatientAppBarActionButton({
    Key? key,
    required this.margin,
    required this.icon,
    required this.iconColor,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColorData = borderColor;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        border: borderColorData == null ? null : Border.all(color: borderColorData),
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
