import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient.dart';
import '../../../theme/app_theme.dart';

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
          _buildHeader(),
          const SizedBox(height: 12),
          if (preselectedPatient == null)
            _buildPatientSelector()
          else
            _buildPreselectedPatient(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Icon(
          Icons.person,
          color: Color(0xFF667eea),
          size: 18,
        ),
        SizedBox(width: 8),
        Text(
          '患者信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF667eea),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientSelector() {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.person,
                    color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: patient == null
                      ? Text(
                          '患者姓名',
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
                                color: Colors.grey.shade600,
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
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreselectedPatient() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: Color(0xFF667eea)),
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
    );
  }
}
