import 'package:flutter/material.dart';

import '../../../models/patient.dart';
import 'patient_statistics_dialog.dart';

class PatientStatisticsNavigation {
  const PatientStatisticsNavigation._();

  static Future<void> open(
    BuildContext context, {
    required List<Patient> patients,
    required String? searchQuery,
    required DateTime? initialStartDate,
    required DateTime? initialEndDate,
    required String dateFilterType,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PatientStatisticsDialog(
          patients: patients,
          searchQuery: searchQuery,
          initialStartDate: initialStartDate,
          initialEndDate: initialEndDate,
          dateFilterType: dateFilterType,
        ),
      ),
    );
  }
}
