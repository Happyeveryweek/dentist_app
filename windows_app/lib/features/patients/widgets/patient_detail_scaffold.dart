import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../widgets/loading_indicator.dart';

class PatientDetailScaffold extends StatelessWidget {
  final String patientName;
  final bool isLoading;
  final TabController tabController;
  final VoidCallback onBack;
  final VoidCallback? onEditPatient;
  final List<Widget> tabViews;

  const PatientDetailScaffold({
    Key? key,
    required this.patientName,
    required this.isLoading,
    required this.tabController,
    required this.onBack,
    required this.onEditPatient,
    required this.tabViews,
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
}
