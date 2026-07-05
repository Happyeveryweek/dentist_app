import 'package:flutter/material.dart';

import '../../../theme/theme_context_extensions.dart';
import '../../../theme/medical_semantic_colors.dart';
import 'patient_form_fields.dart';

class PatientFormBasicSection extends StatelessWidget {
  final TextEditingController medicalRecordController;
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController doctorController;
  final GlobalKey nameFieldKey;
  final bool canEditBasicInfo;
  final String gender;
  final DateTime firstVisitDate;
  final VoidCallback onNameTap;
  final ValueChanged<String> onNameSubmitted;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onSelectDate;

  const PatientFormBasicSection({
    Key? key,
    required this.medicalRecordController,
    required this.nameController,
    required this.ageController,
    required this.doctorController,
    required this.nameFieldKey,
    required this.canEditBasicInfo,
    required this.gender,
    required this.firstVisitDate,
    required this.onNameTap,
    required this.onNameSubmitted,
    required this.onGenderChanged,
    required this.onSelectDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.primaryAccent.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PatientFormTextField(
              controller: medicalRecordController,
              labelText: '病历号',
              hintText: '选填',
              icon: Icons.numbers,
              enabled: canEditBasicInfo,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PatientFormTextField(
              key: nameFieldKey,
              controller: nameController,
              labelText: '姓名',
              hintText: '输入患者姓名',
              icon: Icons.person,
              enabled: canEditBasicInfo,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入姓名';
                }
                return null;
              },
              onTap: onNameTap,
              onChanged: (value) {},
              onFieldSubmitted: onNameSubmitted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: PatientFormTextField(
              controller: ageController,
              labelText: '年龄',
              hintText: '输入年龄',
              icon: Icons.cake,
              enabled: canEditBasicInfo,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (int.tryParse(value) == null) {
                  return '请输入有效年龄';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: PatientFormDropdown(
              value: gender,
              labelText: '性别',
              icon: gender == '男' ? Icons.male : Icons.female,
              enabled: canEditBasicInfo,
              items: const [
                DropdownMenuItem(value: '男', child: Text('男')),
                DropdownMenuItem(value: '女', child: Text('女')),
              ],
              onChanged: onGenderChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: PatientFormTextField(
              controller: doctorController,
              labelText: '主治医生',
              hintText: '选填',
              icon: Icons.medical_services,
              enabled: canEditBasicInfo,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: PatientFormDateField(
              labelText: '首诊日期',
              date: firstVisitDate,
              enabled: canEditBasicInfo,
              onTap: onSelectDate,
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFormContactSection extends StatelessWidget {
  final TextEditingController primaryPhoneController;
  final TextEditingController backupPhoneController;
  final TextEditingController idNumberController;
  final TextEditingController addressController;
  final bool hasBackupPhone;
  final bool canEditBasicInfo;
  final VoidCallback onToggleBackupPhone;

  const PatientFormContactSection({
    Key? key,
    required this.primaryPhoneController,
    required this.backupPhoneController,
    required this.idNumberController,
    required this.addressController,
    required this.hasBackupPhone,
    required this.canEditBasicInfo,
    required this.onToggleBackupPhone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.info.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 1,
                  child: PatientFormTextField(
                    controller: primaryPhoneController,
                    labelText: '主要电话',
                    hintText: '输入11位手机号码',
                    icon: Icons.phone,
                    enabled: canEditBasicInfo,
                    keyboardType: TextInputType.phone,
                    validator: _validatePhone,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: hasBackupPhone
                        ? tokens.error.withValues(alpha: 0.1)
                        : tokens.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      hasBackupPhone ? Icons.remove_circle : Icons.add_circle,
                      color: canEditBasicInfo
                          ? (hasBackupPhone
                              ? tokens.error
                              : tokens.info)
                          : tokens.disabledText,
                    ),
                    tooltip: hasBackupPhone ? '移除备用电话' : '添加备用电话',
                    onPressed: canEditBasicInfo ? onToggleBackupPhone : null,
                  ),
                ),
                if (hasBackupPhone)
                  Flexible(
                    flex: 1,
                    child: PatientFormTextField(
                      controller: backupPhoneController,
                      labelText: '备用电话',
                      hintText: '输入11位手机号码',
                      icon: Icons.phone_forwarded,
                      enabled: canEditBasicInfo,
                      keyboardType: TextInputType.phone,
                      validator: _validateOptionalPhone,
                    ),
                  )
                else
                  Flexible(
                    flex: 1,
                    child: Container(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: PatientFormTextField(
              controller: idNumberController,
              labelText: '身份证号',
              hintText: '选填',
              icon: Icons.badge,
              enabled: canEditBasicInfo,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PatientFormTextField(
              controller: addressController,
              labelText: '住址',
              hintText: '选填住址信息',
              icon: Icons.location_on,
              enabled: canEditBasicInfo,
            ),
          ),
        ],
      ),
    );
  }

  static String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    final RegExp phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return '请输入正确的11位手机号码';
    }
    return null;
  }

  static String? _validateOptionalPhone(String? value) {
    if (value != null && value.isNotEmpty) {
      return _validatePhone(value);
    }
    return null;
  }
}

class PatientFormTreatmentSection extends StatelessWidget {
  final TextEditingController treatmentItemsController;
  final bool canEditBasicInfo;

  const PatientFormTreatmentSection({
    Key? key,
    required this.treatmentItemsController,
    required this.canEditBasicInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.success.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: PatientFormTextField(
        controller: treatmentItemsController,
        labelText: '治疗项目',
        hintText: '填写患者需要的治疗项目',
        icon: Icons.healing,
        enabled: canEditBasicInfo,
        maxLines: 2,
      ),
    );
  }
}

class PatientFormDentalConditionSection extends StatelessWidget {
  final Widget child;

  const PatientFormDentalConditionSection({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tokens.subtleHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
