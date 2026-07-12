import 'dart:collection';
import 'dart:convert';

List<String> normalizeAppointmentTreatments(Iterable<String> items) {
  return LinkedHashSet<String>.from(
    items.map((item) => item.trim()).where((item) => item.isNotEmpty),
  ).toList();
}

List<String> extractAppointmentTreatments(String? source) {
  if (source == null || source.trim().isEmpty) {
    return [];
  }

  final trimmed = source.trim();
  try {
    final decoded = json.decode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return extractAppointmentTreatmentsFromMap(decoded);
    }
    if (decoded is List) {
      return normalizeAppointmentTreatments(
        decoded.map((item) => item.toString()),
      );
    }
  } catch (_) {}

  return normalizeAppointmentTreatments(trimmed.split(RegExp(r'[、,，\n]')));
}

List<String> extractAppointmentTreatmentsFromMap(
  Map<String, dynamic> data,
) {
  for (final key in ['treatments', 'treatmentTypes']) {
    final value = data[key];
    if (value is List) {
      return normalizeAppointmentTreatments(
        value.map((item) => item.toString()),
      );
    }
  }

  final treatmentType = data['treatmentType'];
  if (treatmentType is String) {
    return normalizeAppointmentTreatments([treatmentType]);
  }

  return [];
}

String buildAppointmentTreatmentData(
  Iterable<String> treatments, {
  Iterable<Map<String, String>> teethData = const [],
}) {
  return json.encode({
    'teethData': teethData.toList(),
    'treatments': normalizeAppointmentTreatments(treatments),
  });
}
