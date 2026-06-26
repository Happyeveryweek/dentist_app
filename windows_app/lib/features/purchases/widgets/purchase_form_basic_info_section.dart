import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/modern_date_picker.dart';

/// 采购记录表单的基本信息输入区域
/// 包含：采购日期、供应商、采购医生、备注
class PurchaseFormBasicInfoSection extends StatelessWidget {
  final TextEditingController dateController;
  final TextEditingController supplierController;
  final TextEditingController doctorController;
  final TextEditingController notesController;
  final bool isEditing;
  final DateTime? initialDate;

  const PurchaseFormBasicInfoSection({
    super.key,
    required this.dateController,
    required this.supplierController,
    required this.doctorController,
    required this.notesController,
    required this.isEditing,
    this.initialDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '基本信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: dateController,
                      decoration: InputDecoration(
                        labelText: '采购日期 *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon:
                            Icon(Icons.calendar_today, color: Colors.blue[600]),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDialog<DateTime>(
                          context: context,
                          builder: (context) => ModernDatePickerDialog(
                            initialDate: isEditing
                                ? (initialDate ?? DateTime.now())
                                : DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            title: '选择采购日期',
                          ),
                        );
                        if (date != null) {
                          dateController.text =
                              DateFormat('yyyy-MM-dd').format(date);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: supplierController,
                    decoration: InputDecoration(
                      labelText: '供应商',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon:
                          Icon(Icons.business, color: Colors.green[600]),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: doctorController,
                    decoration: InputDecoration(
                      labelText: '采购医生',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.person, color: Colors.purple[600]),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: '备注',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.note, color: Colors.orange[600]),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
