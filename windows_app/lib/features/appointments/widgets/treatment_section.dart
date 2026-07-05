import 'package:flutter/material.dart';

import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 治疗项目区域
///
/// 显示治疗项目输入框、添加按钮、已选治疗项目列表
class TreatmentSection extends StatelessWidget {
  final TextEditingController treatmentTypeController;
  final List<String> selectedTreatments;
  final VoidCallback onShowTreatmentSelectionDialog;
  final Function(String) onAddCustomTreatment;
  final VoidCallback onUpdateTreatmentTypeController;
  final Function(String) onRemoveTreatment;

  const TreatmentSection({
    Key? key,
    required this.treatmentTypeController,
    required this.selectedTreatments,
    required this.onShowTreatmentSelectionDialog,
    required this.onAddCustomTreatment,
    required this.onUpdateTreatmentTypeController,
    required this.onRemoveTreatment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

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
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildInputRow(context),
          if (selectedTreatments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSelectedTreatments(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Row(
      children: [
        Icon(
          Icons.healing,
          color: tokens.warning,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '治疗项目',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.warning,
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tokens.warning,
                tokens.warningAccent,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: tokens.warning.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextButton.icon(
            icon: Icon(
              Icons.arrow_drop_down,
              color: colors.onPrimary,
              size: 18,
            ),
            label: Text(
              '选择',
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            onPressed: onShowTreatmentSelectionDialog,
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputRow(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: treatmentTypeController,
            decoration: InputDecoration(
              hintText: '输入治疗项目',
              hintStyle: TextStyle(color: tokens.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.warning),
              ),
              filled: true,
              fillColor: tokens.cardBackground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) {},
            onSubmitted: (value) {
              onAddCustomTreatment(value);
            },
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tokens.warning,
                tokens.warningAccent,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: tokens.warning.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              onAddCustomTreatment(treatmentTypeController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: const Text(
              '添加',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTreatments(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: tokens.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: tokens.warning,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '已选治疗项目:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedTreatments
                .map((treatment) => _buildTreatmentChip(context, treatment))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentChip(BuildContext context, String treatment) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.warning.withValues(alpha: 0.1),
            tokens.warningAccent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tokens.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            onRemoveTreatment(treatment);
            onUpdateTreatmentTypeController();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  treatment,
                  style: TextStyle(
                    fontSize: 10,
                    color: tokens.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.close,
                  size: 12,
                  color: tokens.warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
