import 'package:flutter/material.dart';

import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class PatientAdvancedSearchFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController medicalRecordController;
  final VoidCallback onReset;
  final VoidCallback onSearch;

  const PatientAdvancedSearchFields({
    Key? key,
    required this.nameController,
    required this.addressController,
    required this.phoneController,
    required this.medicalRecordController,
    required this.onReset,
    required this.onSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tokens.primaryAccent.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompactSearchField(
              controller: nameController,
              labelText: '姓名',
              hintText: '姓名/拼音/首字母',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactSearchField(
              controller: addressController,
              labelText: '地址',
              hintText: '地址/拼音',
              icon: Icons.location_on_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactSearchField(
              controller: phoneController,
              labelText: '电话',
              hintText: '电话号码',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CompactSearchField(
              controller: medicalRecordController,
              labelText: '病历号',
              hintText: '病历号',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重置'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('搜索'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primaryAccent,
              foregroundColor: tokens.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData icon;
  final TextInputType keyboardType;

  const _CompactSearchField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.icon,
    this.keyboardType = TextInputType.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: tokens.primaryAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.primaryAccent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 18,
              color: tokens.primaryAccent,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.primaryAccent.withValues(alpha: 0.7),
                ),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: tokens.textMuted.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              keyboardType: keyboardType,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
