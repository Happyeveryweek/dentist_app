import '../../../models/patient_sync_log.dart';
import '../../../utils/datetime_formatter.dart';

class PatientSyncLogHelper {
  static List<PatientSyncFieldChange> buildCreateChanges(
    Map<String, dynamic> values,
    Map<String, String> fields,
  ) {
    return fields.entries
        .where((entry) => normalizeValue(values[entry.key]).isNotEmpty)
        .map(
          (entry) => PatientSyncFieldChange(
            field: entry.key,
            label: entry.value,
            oldValue: null,
            newValue: displayValue(values[entry.key]),
          ),
        )
        .toList();
  }

  static List<PatientSyncFieldChange> buildFieldChanges({
    required Map<String, dynamic> oldValues,
    required Map<String, dynamic> newValues,
    required Map<String, String> fields,
  }) {
    final changes = <PatientSyncFieldChange>[];
    for (final entry in fields.entries) {
      final oldValue = normalizeValue(oldValues[entry.key]);
      final newValue = normalizeValue(newValues[entry.key]);
      if (oldValue == newValue) continue;
      changes.add(
        PatientSyncFieldChange(
          field: entry.key,
          label: entry.value,
          oldValue: displayValue(oldValues[entry.key]),
          newValue: displayValue(newValues[entry.key]),
        ),
      );
    }
    return changes;
  }

  static String normalizeValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return DateTimeFormatter.toDbString(value);
    if (value is List<int>) return '${value.length} bytes';
    return value.toString().trim();
  }

  static String? displayValue(dynamic value) {
    final normalized = normalizeValue(value);
    return normalized.isEmpty ? null : normalized;
  }

  static String? extractSummaryValue(String? summary, String key) {
    if (summary == null || summary.isEmpty) return null;
    final pattern = RegExp('(?:^|, )$key=([^,]*)');
    final match = pattern.firstMatch(summary);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
