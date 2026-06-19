import 'package:flutter/material.dart';

import '../../../models/patient.dart';
import 'material_detail_manager.dart';

class PatientMaterialsTab extends StatelessWidget {
  final Patient? patient;
  final VoidCallback onMaterialsChanged;

  const PatientMaterialsTab({
    Key? key,
    required this.patient,
    required this.onMaterialsChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentPatient = patient;
    if (currentPatient == null) {
      return const Center(child: Text('无法加载患者信息'));
    }

    return MaterialDetailManager(
      patient: currentPatient,
      onMaterialsChanged: onMaterialsChanged,
    );
  }
}
