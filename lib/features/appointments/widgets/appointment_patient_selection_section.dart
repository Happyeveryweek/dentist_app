import 'package:flutter/material.dart';
import '../../../models/patient.dart';
import '../../../theme/app_theme.dart';

class AppointmentPatientSelectionSection extends StatelessWidget {
  final Patient? selectedPatient;
  final bool hasPreselectedPatient;
  final bool isLoadingPatients;
  final VoidCallback onSelectPatient;

  const AppointmentPatientSelectionSection({
    Key? key,
    required this.selectedPatient,
    required this.hasPreselectedPatient,
    required this.isLoadingPatients,
    required this.onSelectPatient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: const Color(0xFF667eea),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667eea),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasPreselectedPatient)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: const Color(0xFF667eea)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '患者: ${selectedPatient?.name ?? '未选择'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667eea),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isLoadingPatients)
            const Center(child: CircularProgressIndicator())
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSelectPatient,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: selectedPatient == null
                            ? Text(
                                '请选择患者',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedPatient!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '最近就诊: ${selectedPatient!.updated_at.year.toString().padLeft(4, '0')}-${selectedPatient!.updated_at.month.toString().padLeft(2, '0')}-${selectedPatient!.updated_at.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
