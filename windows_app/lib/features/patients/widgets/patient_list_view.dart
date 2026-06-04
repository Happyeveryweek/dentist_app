import 'package:flutter/material.dart';

import '../../../models/patient.dart';
import 'patient_list_item.dart';

class PatientListView extends StatelessWidget {
  final List<Patient> patients;
  final bool Function(Patient patient) canEditPatient;
  final bool Function(Patient patient) canDeletePatient;
  final void Function(Patient patient) onView;
  final void Function(Patient patient) onEdit;
  final void Function(Patient patient) onDelete;
  final VoidCallback onEditPermissionDenied;
  final VoidCallback onDeletePermissionDenied;

  const PatientListView({
    Key? key,
    required this.patients,
    required this.canEditPatient,
    required this.canDeletePatient,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onEditPermissionDenied,
    required this.onDeletePermissionDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];

        return PatientListItem(
          patient: patient,
          canEdit: canEditPatient(patient),
          canDelete: canDeletePatient(patient),
          onView: () => onView(patient),
          onEdit: () => onEdit(patient),
          onDelete: () => onDelete(patient),
          onEditPermissionDenied: onEditPermissionDenied,
          onDeletePermissionDenied: onDeletePermissionDenied,
        );
      },
    );
  }
}
