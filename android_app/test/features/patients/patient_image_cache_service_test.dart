import 'package:dentist_app/features/patients/services/patient_image_cache_service.dart';
import 'package:dentist_app/models/material_image.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('清除患者缓存时一并清除关联图片', () {
    final cache = PatientImageCacheService(() {});
    final now = DateTime(2026);
    cache.updatePatientMaterialsCache(1, [
      PatientMaterial(
        id: 10,
        patientId: 1,
        description: '术前',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    cache.updateMaterialImagesCache(10, [
      MaterialImage(
        id: 100,
        materialId: 10,
        imageData: const [1],
        imageType: 'jpg',
        createdAt: now,
      ),
    ]);

    cache.clearPatientCache(1);

    expect(cache.getPatientMaterialsCache(1), isNull);
    expect(cache.getMaterialImagesCache(10), isNull);
    cache.dispose();
  });
}
