import 'dart:typed_data';

import 'package:dentist_app_windows/features/patients/services/patient_material_sync_service.dart';
import 'package:dentist_app_windows/models/material_image.dart';
import 'package:dentist_app_windows/models/patient_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final material = PatientMaterial(
    id: 39,
    patientId: 1697,
    description: '正畸前照片',
  );
  final image = MaterialImage(
    id: 104,
    materialId: 39,
    imageData: Uint8List(0),
    imageType: 'jpg',
    fileSize: 81794,
    originalName: 'MVIMG_20260913_184708.jpg',
  );

  test('MySQL 缺少材料图片时判定为未同步', () {
    expect(
      PatientMaterialSyncSnapshot.matches(
        materials: [material],
        imagesByMaterialId: {
          39: [image],
        },
        mysqlMaterials: const [
          {'id': 39, 'description': '正畸前照片'},
        ],
        mysqlImages: const [],
      ),
      isFalse,
    );
  });

  test('材料描述和图片大小一致时判定为已同步', () {
    expect(
      PatientMaterialSyncSnapshot.matches(
        materials: [material],
        imagesByMaterialId: {
          39: [image],
        },
        mysqlMaterials: const [
          {'id': 39, 'description': '正畸前照片'},
        ],
        mysqlImages: const [
          {
            'id': 104,
            'material_id': 39,
            'original_name': 'MVIMG_20260913_184708.jpg',
            'image_type': 'jpg',
            'file_size': 81794,
          },
        ],
      ),
      isTrue,
    );
  });

  test('MySQL 多出的材料或图片判定为未同步', () {
    expect(
      PatientMaterialSyncSnapshot.matches(
        materials: [material],
        imagesByMaterialId: {
          39: [image],
        },
        mysqlMaterials: const [
          {'id': 39, 'description': '正畸前照片'},
          {'id': 40, 'description': '已删除材料'},
        ],
        mysqlImages: const [
          {
            'id': 104,
            'material_id': 39,
            'original_name': 'MVIMG_20260913_184708.jpg',
            'image_type': 'jpg',
            'file_size': 81794,
          },
        ],
      ),
      isFalse,
    );
    expect(
      PatientMaterialSyncSnapshot.matches(
        materials: [material],
        imagesByMaterialId: {
          39: [image],
        },
        mysqlMaterials: const [
          {'id': 39, 'description': '正畸前照片'},
        ],
        mysqlImages: const [
          {
            'id': 104,
            'material_id': 39,
            'original_name': 'MVIMG_20260913_184708.jpg',
            'image_type': 'jpg',
            'file_size': 81794,
          },
          {
            'id': 105,
            'material_id': 39,
            'original_name': 'deleted.jpg',
            'image_type': 'jpg',
            'file_size': 10,
          },
        ],
      ),
      isFalse,
    );
  });

  test('材料描述或图片大小不同时判定为未同步', () {
    expect(
      PatientMaterialSyncSnapshot.matches(
        materials: [material],
        imagesByMaterialId: {
          39: [image],
        },
        mysqlMaterials: const [
          {'id': 39, 'description': '治疗后照片'},
        ],
        mysqlImages: const [
          {
            'id': 104,
            'material_id': 39,
            'original_name': 'MVIMG_20260913_184708.jpg',
            'image_type': 'jpg',
            'file_size': 81794,
          },
        ],
      ),
      isFalse,
    );
    expect(
      PatientMaterialSyncSnapshot.matches(
        materials: [material],
        imagesByMaterialId: {
          39: [image],
        },
        mysqlMaterials: const [
          {'id': 39, 'description': '正畸前照片'},
        ],
        mysqlImages: const [
          {
            'id': 104,
            'material_id': 39,
            'original_name': 'MVIMG_20260913_184708.jpg',
            'image_type': 'jpg',
            'file_size': 1,
          },
        ],
      ),
      isFalse,
    );
  });
}
