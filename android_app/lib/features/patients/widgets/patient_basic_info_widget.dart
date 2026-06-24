import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';

/// 患者基本信息表单组件
/// 职责：管理患者基本信息表单字段
class PatientBasicInfoWidget extends StatefulWidget {
  final String? initialName;
  final String? initialAge;
  final String? initialGender;
  final String? initialAddress;
  final String? initialIdNumber;
  final String? initialDoctor;
  final String? initialMedicalRecordNumber;
  final String? initialTreatmentItems;
  final DateTime? initialFirstVisitDate;
  final Function(Map<String, dynamic>) onInfoChanged;

  const PatientBasicInfoWidget({
    Key? key,
    this.initialName,
    this.initialAge,
    this.initialGender,
    this.initialAddress,
    this.initialIdNumber,
    this.initialDoctor,
    this.initialMedicalRecordNumber,
    this.initialTreatmentItems,
    this.initialFirstVisitDate,
    required this.onInfoChanged,
  }) : super(key: key);

  @override
  PatientBasicInfoWidgetState createState() =>
      PatientBasicInfoWidgetState();
}

class PatientBasicInfoWidgetState extends State<PatientBasicInfoWidget> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = '男';
  final _addressController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _doctorController = TextEditingController();
  final _medicalRecordController = TextEditingController();
  final _treatmentItemsController = TextEditingController();
  DateTime _firstVisitDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _ageController.text = widget.initialAge ?? '';
    _gender = widget.initialGender == '女' ? '女' : '男';
    _addressController.text = widget.initialAddress ?? '';
    _idNumberController.text = widget.initialIdNumber ?? '';
    _doctorController.text = widget.initialDoctor ?? '';
    _medicalRecordController.text = widget.initialMedicalRecordNumber ?? '';
    _treatmentItemsController.text = widget.initialTreatmentItems ?? '';
    if (widget.initialFirstVisitDate != null) {
      _firstVisitDate = widget.initialFirstVisitDate!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _doctorController.dispose();
    _medicalRecordController.dispose();
    _treatmentItemsController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onInfoChanged({
      'name': _nameController.text,
      'age': _ageController.text,
      'gender': _gender,
      'address': _addressController.text,
      'idNumber': _idNumberController.text,
      'doctor': _doctorController.text,
      'medicalRecordNumber': _medicalRecordController.text,
      'treatmentItems': _treatmentItemsController.text,
      'firstVisitDate': _firstVisitDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 患者基本信息标题
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 0, 16),
          child: Text(
            '基本信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 姓名、年龄行
        Row(
          children: [
            // 姓名
            Expanded(
              child: _buildInfoField(
                icon: Icons.badge,
                iconColor: Colors.blue,
                label: '姓名',
                controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入姓名';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            // 年龄
            Expanded(
              child: _buildInfoField(
                icon: Icons.cake,
                iconColor: Colors.orange,
                label: '年龄',
                controller: _ageController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入年龄';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        // 性别
        _buildGenderSelector(),

        // 地址
        _buildInfoField(
          icon: Icons.home,
          iconColor: Colors.amber,
          label: '地址',
          controller: _addressController,
        ),

        // 身份证号
        _buildInfoField(
          icon: Icons.credit_card,
          iconColor: Colors.indigo,
          label: '身份证号',
          controller: _idNumberController,
        ),

        // 主治医生
        _buildInfoField(
          icon: Icons.healing,
          iconColor: Colors.red,
          label: '主治医生',
          controller: _doctorController,
        ),

        // 病历号
        _buildInfoField(
          icon: Icons.description,
          iconColor: Colors.purple,
          label: '病历号',
          controller: _medicalRecordController,
          keyboardType: TextInputType.number,
        ),

        // 首诊日期卡片
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 0,
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () async {
              final pickedDate = await showDialog<DateTime>(
                context: context,
                builder: (BuildContext context) {
                  return ModernDatePickerDialog(
                    initialDate: _firstVisitDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                },
              );
              if (pickedDate != null) {
                setState(() {
                  _firstVisitDate = pickedDate;
                });
                _notifyChange();
              }
            },
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: '首诊日期',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    color: Colors.orange.shade700,
                  ),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                controller: TextEditingController(
                  text: DateFormat('yyyy-MM-dd').format(_firstVisitDate),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        // 治疗项目卡片
        _buildTreatmentItemField(),
      ],
    );
  }

  // 构建性别选择器
  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '性别',
          prefixIcon: Icon(Icons.wc, color: Colors.pink.shade400),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: RadioGroup<String>(
                groupValue: _gender,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _gender = value;
                    });
                    _notifyChange();
                  }
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: '男',
                      fillColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) =>
                            states.contains(WidgetState.selected)
                                ? Colors.blue
                                : null,
                      ),
                    ),
                    const Text('男', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 24),
                    Radio<String>(
                      value: '女',
                      fillColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) =>
                            states.contains(WidgetState.selected)
                                ? Colors.pink
                                : null,
                      ),
                    ),
                    const Text('女', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建美化的信息输入字段
  Widget _buildInfoField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          alignLabelWithHint: maxLines > 1,
          prefixIcon: Icon(
            icon,
            color: iconColor.withValues(alpha: 0.8),
            size: 22,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 16 : 16,
          ),
          isDense: true,
        ),
        onChanged: (value) {
          _notifyChange();
        },
      ),
    );
  }

  // 治疗项目输入框
  Widget _buildTreatmentItemField() {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      color: Colors.transparent,
      child: TextFormField(
        controller: _treatmentItemsController,
        maxLines: 3,
        style: const TextStyle(fontSize: 16, height: 1.5),
        decoration: InputDecoration(
          labelText: '治疗项目',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          alignLabelWithHint: true,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Icon(Icons.medical_services, color: Colors.teal.shade700),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onChanged: (value) {
          _notifyChange();
        },
      ),
    );
  }
}
