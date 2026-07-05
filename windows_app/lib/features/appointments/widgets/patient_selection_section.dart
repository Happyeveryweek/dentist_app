import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 患者选择区域
///
/// 显示患者选择框、选择按钮、预选患者信息
class PatientSelectionSection extends StatelessWidget {
  final Patient? preselectedPatient;
  final Patient? selectedPatient;
  final bool isLoadingPatients;
  final VoidCallback onShowPatientSearchDialog;

  const PatientSelectionSection({
    Key? key,
    required this.preselectedPatient,
    required this.selectedPatient,
    required this.isLoadingPatients,
    required this.onShowPatientSearchDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tokens),
          const SizedBox(height: 12),
          if (preselectedPatient == null)
            _buildPatientSelector(context, tokens, colors)
          else
            _buildPreselectedPatient(tokens),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeTokens tokens) {
    return Row(
      children: [
        Icon(
          Icons.person,
          color: tokens.primaryAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '患者信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.primaryAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientSelector(
    BuildContext context,
    AppThemeTokens tokens,
    ColorScheme colors,
  ) {
    final patient = selectedPatient;
    if (isLoadingPatients) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: tokens.primaryAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: patient == null
                      ? Text(
                          '患者姓名',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '最近就诊: ${DateFormat('yyyy-MM-dd').format(patient.updatedAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: onShowPatientSearchDialog,
          icon: const Icon(Icons.search, size: 18),
          label: const Text('选择'),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.primaryAccent,
            foregroundColor: colors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreselectedPatient(AppThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: tokens.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: tokens.primaryAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '患者: ${selectedPatient?.name ?? '未选择'}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.primaryAccent,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
