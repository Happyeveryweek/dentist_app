class PatientSearchCriteriaService {
  const PatientSearchCriteriaService._();

  static Map<String, String> buildAdvancedCriteria({
    required String name,
    required String address,
    required String phone,
    required String medicalRecord,
  }) {
    final trimmedName = name.trim();
    final trimmedAddress = address.trim();
    final trimmedPhone = phone.trim();
    final trimmedMedicalRecord = medicalRecord.trim();

    return <String, String>{
      if (trimmedName.isNotEmpty) 'name': trimmedName,
      if (trimmedAddress.isNotEmpty) 'address': trimmedAddress,
      if (trimmedPhone.isNotEmpty) 'phone': trimmedPhone,
      if (trimmedMedicalRecord.isNotEmpty)
        'medical_record': trimmedMedicalRecord,
    };
  }
}
