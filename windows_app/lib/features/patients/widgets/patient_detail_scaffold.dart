import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../widgets/loading_indicator.dart';

/// 患者数据同步状态
enum PatientSyncStatus {
  /// 检查中
  checking,

  /// SQLite 与 MySQL 数据一致
  synced,

  /// SQLite 与 MySQL 数据不一致
  notSynced,

  /// 无法比较（非 SQLite 主库或 MySQL 不可用）
  unavailable,
}

class PatientDetailScaffold extends StatelessWidget {
  final String patientName;
  final bool isLoading;
  final TabController tabController;
  final VoidCallback onBack;
  final VoidCallback? onEditPatient;
  final List<Widget> tabViews;

  /// 患者数据同步状态
  final PatientSyncStatus syncStatus;

  /// 是否正在执行同步
  final bool isSyncing;

  /// 点击同步按钮回调
  final VoidCallback? onSync;

  const PatientDetailScaffold({
    Key? key,
    required this.patientName,
    required this.isLoading,
    required this.tabController,
    required this.onBack,
    required this.onEditPatient,
    required this.tabViews,
    this.syncStatus = PatientSyncStatus.checking,
    this.isSyncing = false,
    this.onSync,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_rounded,
                color: context.tokens.cardBackground,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              patientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: context.tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          _buildSyncButton(context),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.tokens.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.tokens.primaryAccent.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.edit_rounded,
                color: context.tokens.primaryAccent,
              ),
              tooltip: '编辑患者',
              onPressed: onEditPatient,
            ),
          ),
        ],
        bottom: isLoading
            ? null
            : TabBar(
                controller: tabController,
                tabs: const [
                  Tab(text: '基本信息'),
                  Tab(text: '患者病历'),
                  Tab(text: '患者材料'),
                  Tab(text: '预约记录'),
                  Tab(text: '收费记录'),
                ],
              ),
      ),
      body: isLoading
          ? const LoadingIndicator()
          : TabBarView(
              controller: tabController,
              children: tabViews,
            ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    final color = _syncStatusColor(context);
    final icon = _syncStatusIcon;
    final tooltip = _syncStatusTooltip;

    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        icon: isSyncing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onSync,
      ),
    );
  }

  Color _syncStatusColor(BuildContext context) {
    switch (syncStatus) {
      case PatientSyncStatus.synced:
        return context.tokens.success;
      case PatientSyncStatus.notSynced:
        return context.tokens.error;
      case PatientSyncStatus.checking:
      case PatientSyncStatus.unavailable:
        return context.colors.outline;
    }
  }

  IconData get _syncStatusIcon {
    switch (syncStatus) {
      case PatientSyncStatus.synced:
        return Icons.cloud_done_rounded;
      case PatientSyncStatus.notSynced:
        return Icons.cloud_off_rounded;
      case PatientSyncStatus.checking:
        return Icons.sync_rounded;
      case PatientSyncStatus.unavailable:
        return Icons.cloud_off_rounded;
    }
  }

  String get _syncStatusTooltip {
    switch (syncStatus) {
      case PatientSyncStatus.synced:
        return '数据已同步';
      case PatientSyncStatus.notSynced:
        return '数据未同步，点击同步';
      case PatientSyncStatus.checking:
        return '正在检查同步状态';
      case PatientSyncStatus.unavailable:
        return '同步不可用（仅 SQLite 主库支持）';
    }
  }
}
