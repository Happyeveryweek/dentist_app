import 'package:flutter/material.dart';
import 'package:dentist_app/models/database_models.dart';
import 'section_title.dart';

class PatientSelectionSection extends StatelessWidget {
  final Patient? selectedPatient;
  final TextEditingController patientNameController;
  final VoidCallback? onTap;
  final bool isEditingNotesOnly;

  const PatientSelectionSection({
    super.key,
    required this.selectedPatient,
    required this.patientNameController,
    required this.onTap,
    required this.isEditingNotesOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: '患者信息',
          icon: Icons.person,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: patientNameController,
          readOnly: true,
          onTap: isEditingNotesOnly ? null : onTap,
          decoration: InputDecoration(
            hintText: '点击选择患者',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor:
                selectedPatient != null
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            suffixIcon: Icon(
              Icons.search,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
