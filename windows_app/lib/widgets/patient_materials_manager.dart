import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/patient.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../providers/patient_provider.dart';
import '../utils/image_compressor.dart';
import 'material_input_widget.dart';

/// 患者材料管理器组件
/// 
/// 新的表格式保存逻辑：
/// 1. 每行代表一个材料及其所有图片
/// 2. 保存时先保存材料描述，获取ID
/// 3. 再保存该材料行的所有图片，关联到材料ID
/// 4. 删除时使用联表删除确保数据一致性
/// 
/// 优势：
/// - 数据关系更清晰，一行对应一个材料
/// - 保存逻辑更简单，先描述后图片
/// - 减少了复杂的数组索引对应关系
/// - 更容易维护和调试
class PatientMaterialsManager extends StatefulWidget {
  final Patient? patient;
  final GlobalKey<MaterialInputWidgetState> materialInputKey;

  const PatientMaterialsManager({
    Key? key,
    required this.patient,
    required this.materialInputKey,
  }) : super(key: key);

  @override
  State<PatientMaterialsManager> createState() => PatientMaterialsManagerState();
}

class PatientMaterialsManagerState extends State<PatientMaterialsManager> {
  List<PatientMaterialWithImages> _materials = [];

  // 获取当前材料列表
  List<PatientMaterialWithImages> get materials => _materials;

  // 处理材料变化
  void onMaterialsChanged(List<PatientMaterialWithImages> materials) {
    setState(() {
      _materials = materials;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      _loadPatientMaterials();
    }
  }

  // 加载患者材料信息
  Future<void> _loadPatientMaterials() async {
    if (widget.patient == null) return;
    
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      // 优先使用缩略图模式加载，提升性能 - 直接使用患者管理的方法
      final materials = await patientProvider.getPatientMaterialsWithThumbnails(widget.patient!.id!);
      
      setState(() {
        _materials = materials;
      });
      
      print('成功加载患者材料信息（缩略图模式），共 ${materials.length} 个材料');
    } catch (e) {
      print('加载患者材料信息失败: $e');
      setState(() {
        _materials = [];
      });
    }
  }

  // 保存患者材料信息（编辑现有患者时使用）
  Future<void> savePatientMaterials(List<PatientMaterialWithImages> materials) async {
    try {
      print('开始保存患者材料信息...');
      
      // 检查是否是编辑现有患者
      if (widget.patient == null || widget.patient!.id == null) {
        print('不是编辑现有患者，跳过材料保存');
        return;
      }
      
      // 验证表格式数据完整性
      if (!validateTableFormatData(materials)) {
        throw Exception('表格式材料数据验证失败，请检查数据完整性');
      }
      
      // 显示统计信息
      final stats = getTableFormatStats(materials);
      print('表格式材料数据统计: 行数=${stats['totalRows']}, 总图片=${stats['totalImages']}, 新图片=${stats['newImages']}, 现有图片=${stats['existingImages']}');
      
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      // 获取现有材料信息 - 直接使用患者管理的方法
      final existingMaterials = await patientProvider.getPatientMaterialsWithImages(widget.patient!.id!);
      final existingMaterialIds = existingMaterials.map((m) => m.material.id).where((id) => id != null).cast<int>().toSet();
      
      print('现有材料数量: ${existingMaterials.length}, 现有材料ID: $existingMaterialIds');
      
      // 1. 先收集并处理用户在UI中标记为删除的整行材料（优先级高）。
      //    如果先删除整行，数据库会级联删除相关图片，后续针对图片的逐条删除可跳过已经被整行删除的图片。
      final deletedMaterialIds = <int>{};
      if (widget.materialInputKey.currentState != null) {
        final materialsToDelete = widget.materialInputKey.currentState!.materialsToDelete;
        if (materialsToDelete.isNotEmpty) {
          print('开始删除用户在UI中标记为删除的材料，共 ${materialsToDelete.length} 项');
          for (final materialId in materialsToDelete) {
            try {
              final deleteSuccess = await patientProvider.deletePatientMaterial(materialId);
              if (deleteSuccess) {
                deletedMaterialIds.add(materialId);
                print('成功删除材料行: ID=$materialId');
              } else {
                print('删除材料行失败: ID=$materialId');
              }
            } catch (e) {
              print('删除材料行时出错: ID=$materialId, 错误=$e');
            }
          }
        }
      }

      // 2. 处理标记删除的图片，跳过已经属于被整行删除的材料的图片，避免重复删除
      if (widget.materialInputKey.currentState != null) {
        final imagesToDelete = widget.materialInputKey.currentState!.imagesToDelete;
        if (imagesToDelete.isNotEmpty) {
          print('开始处理标记删除的图片，共 ${imagesToDelete.length} 张');

          for (final deleteRecord in imagesToDelete) {
            final imageId = deleteRecord['imageId'] as int;
            final materialId = deleteRecord['materialId'] as int;
            final fileName = deleteRecord['fileName'] as String;

            // 如果整行已经删除，则跳过单张图片删除
            if (deletedMaterialIds.contains(materialId)) {
              print('跳过图片删除(ID=$imageId) - 所属材料(ID=$materialId)已被整行删除');
              continue;
            }

            print('删除图片: ID=$imageId, 材料ID=$materialId, 文件名=$fileName');

            try {
              final deleteSuccess = await patientProvider.deleteMaterialImage(imageId);
              if (deleteSuccess) {
                print('成功删除图片: ID=$imageId, 文件名=$fileName');
              } else {
                print('删除图片失败: ID=$imageId, 文件名=$fileName');
              }
            } catch (e) {
              print('删除图片时出错: ID=$imageId, 错误=$e');
            }
          }
        }
      }

      // 3. 所有删除操作处理完毕后，统一清理UI中的删除记录
      if (widget.materialInputKey.currentState != null) {
        widget.materialInputKey.currentState!.clearDeleteRecords();
        print('已清除图片和材料删除记录');
      }
      
      // 2. 表格式保存逻辑：先保存材料描述，再保存图片
      for (int i = 0; i < materials.length; i++) {
        final materialWithImages = materials[i];
        final material = materialWithImages.material;
        final images = materialWithImages.images;
        // 如果该材料已在之前的整行删除步骤中被删除，跳过它
        if (material.id != null && deletedMaterialIds.contains(material.id)) {
          print('跳过已被整行删除的材料: ID=${material.id}');
          continue;
        }
        
        print('处理材料行 $i: ID=${material.id}, 描述="${material.description}", 图片数量=${images.length}');
        
        // 详细分析图片列表
        int existingImageCount = 0;
        int newImageCount = 0;
        for (final image in images) {
          if (image.id == null || image.id == 0) {
            newImageCount++;
            print('    新图片: 文件路径=${image.originalName}');
          } else {
            existingImageCount++;
            print('    现有图片: ID=${image.id}, 文件名=${image.originalName}');
          }
        }
        print('  材料行 $i 图片分析: 现有图片=$existingImageCount, 新图片=$newImageCount');
        
        PatientMaterial savedMaterial;
        
        if (material.id == null || material.id == 0) {
          // 新材料：先保存材料描述 - 直接使用患者管理的方法
          print('  保存新材料描述: "${material.description}"');
          savedMaterial = await patientProvider.addPatientMaterial(material);
          print('  新材料保存成功: ID=${savedMaterial.id}');
        } else {
          // 更新现有材料描述 - 直接使用患者管理的方法
          print('  更新现有材料描述: ID=${material.id}, 描述="${material.description}"');
          final updateSuccess = await patientProvider.updatePatientMaterial(material);
          if (updateSuccess) {
            savedMaterial = material;
            print('  现有材料更新成功: ID=${savedMaterial.id}');
          } else {
            throw Exception('更新材料失败');
          }
        }
        
        // 3. 保存该材料行的所有图片（先去重，避免重复保存相同图片）
        if (images.isNotEmpty) {
          print('  开始保存材料 ${material.description} 的图片，共 ${images.length} 张');

          // 去重：优先使用 image.id，其次使用 originalName 作为唯一键
          final Map<String, MaterialImage> uniqueMap = {};
          for (final img in images) {
            String key;
            if (img.id != null && img.id! > 0) {
              key = 'id_${img.id}';
            } else if (img.originalName != null && img.originalName!.isNotEmpty) {
              key = 'path_${img.originalName}';
            } else {
              // fallback: use object hash
              key = 'obj_${img.hashCode}';
            }
            if (!uniqueMap.containsKey(key)) {
              uniqueMap[key] = img;
            } else {
              print('    跳过重复图片记录: key=$key');
            }
          }

          final uniqueImages = uniqueMap.values.toList();
          print('  去重后图片数量: ${uniqueImages.length}');

          for (int j = 0; j < uniqueImages.length; j++) {
            final image = uniqueImages[j];

            if (image.id == null || image.id == 0) {
              // 新图片：检查是否有文件路径信息
              if (image.originalName != null && image.originalName!.isNotEmpty && 
                  !image.originalName!.startsWith('http') && !image.originalName!.startsWith('file://')) {
                
                print('    保存新图片 $j: 文件路径=${image.originalName}');
                
                try {
                  final file = File(image.originalName!);
                  if (await file.exists()) {
                    print('    文件存在，开始处理...');
                    // 压缩图片并生成缩略图
                    final compressedResult = await ImageCompressor.compressImageFile(file);
                    final thumbnailBytes = await ImageCompressor.generateThumbnail(compressedResult.compressedBytes);
                    final thumbnailSize = thumbnailBytes.length;
                    
                    final materialImage = MaterialImage(
                      materialId: savedMaterial.id!,
                      imageData: compressedResult.compressedBytes,
                      imageType: compressedResult.imageType,
                      fileSize: compressedResult.compressedSize,
                      thumbnailData: thumbnailBytes,
                      thumbnailSize: thumbnailSize,
                      originalName: path.basename(image.originalName!),
                      hasThumbnail: true,
                    );
                    
                    final savedImage = await patientProvider.addMaterialImage(materialImage);
                    print('    新图片保存成功: ID=${savedImage.id}, 包含缩略图');
                  } else {
                    print('    新图片文件不存在: ${image.originalName}');
                  }
                } catch (e) {
                  print('    保存新图片失败: $e');
                  // 回退方案：只保存原图
                  try {
                    final file = File(image.originalName!);
                    if (await file.exists()) {
                      final compressedResult = await ImageCompressor.compressImageFile(file);
                      final materialImage = MaterialImage(
                        materialId: savedMaterial.id!,
                        imageData: compressedResult.compressedBytes,
                        imageType: compressedResult.imageType,
                        fileSize: compressedResult.compressedSize,
                        originalName: path.basename(image.originalName!),
                        hasThumbnail: false,
                      );
                      
                      final savedImage = await patientProvider.addMaterialImage(materialImage);
                      print('    新图片保存成功（仅原图）: ID=${savedImage.id}');
                    }
                  } catch (fallbackError) {
                    print('    保存新图片失败（回退方案）: $fallbackError');
                  }
                }
              } else {
                print('    跳过图片 $j: 没有有效的文件路径信息, originalName=${image.originalName}');
              }
            } else {
              print('    跳过现有图片 $j: ID=${image.id}');
            }
          }
        } else {
          print('  材料 ${material.description} 没有图片需要保存');
        }
      }
      
      // 4. 删除不再存在的材料行
      final currentMaterialIds = materials.map((m) => m.material.id).where((id) => id != null).cast<int>().toSet();
      final materialsToDelete = existingMaterialIds.difference(currentMaterialIds);
      
      print('需要删除的材料数量: ${materialsToDelete.length}');
      for (final materialId in materialsToDelete) {
        print('开始删除材料行: ID=$materialId');
        
        // 获取要删除的材料信息，用于日志记录
        final materialToDelete = existingMaterials.firstWhere(
          (m) => m.material.id == materialId,
          orElse: () => PatientMaterialWithImages(
            material: PatientMaterial(patientId: 0, description: ''),
            images: [],
          ),
        );
        
        print('删除材料详情: ID=$materialId, 描述=${materialToDelete.material.description}, 图片数量=${materialToDelete.images.length}');
        
        // 删除材料（PatientProvider的deletePatientMaterial方法会使用联表删除确保图片被正确删除）
        final deleteSuccess = await patientProvider.deletePatientMaterial(materialId);
        if (deleteSuccess) {
          print('成功删除材料行: ID=$materialId');
        } else {
          print('删除材料行失败: ID=$materialId');
          // 注意：这里不抛出异常，因为删除失败不应该阻止其他材料的保存
        }
      }
      
      print('成功保存患者材料信息（表格式逻辑）');
    } catch (e) {
      print('保存患者材料信息失败: $e');
      rethrow;
    }
  }

  // 保存新患者的材料信息（在患者保存后调用）
  Future<void> saveNewPatientMaterials(int patientId, List<PatientMaterialWithImages> materials) async {
    try {
      print('开始保存新患者材料信息（表格式逻辑）: 患者ID=$patientId');
      
      // 验证表格式数据完整性
      if (!validateTableFormatData(materials)) {
        throw Exception('表格式材料数据验证失败，请检查数据完整性');
      }
      
      // 显示统计信息
      final stats = getTableFormatStats(materials);
      print('新患者表格式材料数据统计: 行数=${stats['totalRows']}, 总图片=${stats['totalImages']}, 新图片=${stats['newImages']}');
      
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      // 表格式保存逻辑：先保存材料描述，再保存图片
      for (int i = 0; i < materials.length; i++) {
        final materialWithImages = materials[i];
        final material = materialWithImages.material.copyWith(patientId: patientId);
        final images = materialWithImages.images;
        
        print('处理材料行 $i: 描述="${material.description}", 图片数量=${images.length}');
        
        // 1. 先保存材料描述 - 直接使用患者管理的方法
        final savedMaterial = await patientProvider.addPatientMaterial(material);
        print('  材料描述保存成功: ID=${savedMaterial.id}');
        
        // 2. 再保存该材料行的所有图片（先去重）
        if (images.isNotEmpty) {
          print('  开始保存材料 ${material.description} 的图片，共 ${images.length} 张');

          // 去重：优先使用 image.id，其次使用 originalName 作为唯一键
          final Map<String, MaterialImage> uniqueMap = {};
          for (final img in images) {
            String key;
            if (img.id != null && img.id! > 0) {
              key = 'id_${img.id}';
            } else if (img.originalName != null && img.originalName!.isNotEmpty) {
              key = 'path_${img.originalName}';
            } else {
              key = 'obj_${img.hashCode}';
            }
            if (!uniqueMap.containsKey(key)) {
              uniqueMap[key] = img;
            } else {
              print('    跳过重复图片记录: key=$key');
            }
          }

          final uniqueImages = uniqueMap.values.toList();
          print('  去重后图片数量: ${uniqueImages.length}');

          for (int j = 0; j < uniqueImages.length; j++) {
            final image = uniqueImages[j];
            
            // 新图片：检查是否有文件路径信息
            if (image.originalName != null && image.originalName!.isNotEmpty && 
                !image.originalName!.startsWith('http') && !image.originalName!.startsWith('file://')) {
              
              print('    保存新图片 $j: 文件路径=${image.originalName}');
              
              try {
                final file = File(image.originalName!);
                if (await file.exists()) {
                  // 压缩图片并生成缩略图
                  final compressedResult = await ImageCompressor.compressImageFile(file);
                  final thumbnailBytes = await ImageCompressor.generateThumbnail(compressedResult.compressedBytes);
                  final thumbnailSize = thumbnailBytes.length;
                  
                  final materialImage = MaterialImage(
                    materialId: savedMaterial.id!,
                    imageData: compressedResult.compressedBytes,
                    imageType: compressedResult.imageType,
                    fileSize: compressedResult.compressedSize,
                    thumbnailData: thumbnailBytes,
                    thumbnailSize: thumbnailSize,
                    originalName: path.basename(image.originalName!),
                    hasThumbnail: true,
                  );
                  
                  final savedImage = await patientProvider.addMaterialImage(materialImage);
                  print('    新图片保存成功: ID=${savedImage.id}, 包含缩略图');
                } else {
                  print('    新图片文件不存在: ${image.originalName}');
                }
              } catch (e) {
                print('    保存新图片失败: $e');
                // 回退方案：只保存原图
                try {
                  final file = File(image.originalName!);
                  if (await file.exists()) {
                    final compressedResult = await ImageCompressor.compressImageFile(file);
                    final materialImage = MaterialImage(
                      materialId: savedMaterial.id!,
                      imageData: compressedResult.compressedBytes,
                      imageType: compressedResult.imageType,
                      fileSize: compressedResult.compressedSize,
                      originalName: path.basename(image.originalName!),
                      hasThumbnail: false,
                    );
                    
                    final savedImage = await patientProvider.addMaterialImage(materialImage);
                    print('    新图片保存成功（仅原图）: ID=${savedImage.id}');
                  }
                } catch (fallbackError) {
                  print('    保存新图片失败（回退方案）: $fallbackError');
                }
              }
            } else {
              print('    跳过图片 $j: 没有有效的文件路径信息');
            }
          }
        } else {
          print('  材料 ${material.description} 没有图片需要保存');
        }
      }
      
      print('新患者材料信息保存完成（表格式逻辑）');
    } catch (e) {
      print('保存新患者材料信息失败: $e');
      rethrow;
    }
  }

  // 加载已存在患者的材料信息
  Future<void> loadExistingPatientMaterials(int patientId) async {
    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      // 优先使用缩略图模式加载，提升性能 - 直接使用患者管理的方法
      final materials = await patientProvider.getPatientMaterialsWithThumbnails(patientId);
      
      setState(() {
        _materials = materials;
      });
      
      print('成功加载已存在患者材料信息（缩略图模式），共 ${materials.length} 个材料');
    } catch (e) {
      print('加载已存在患者材料信息失败: $e');
      setState(() {
        _materials = [];
      });
    }
  }

  /// 验证表格式材料数据的完整性
  /// 确保每行都有描述，图片都正确关联
  bool validateTableFormatData(List<PatientMaterialWithImages> materials) {
    print('验证表格式材料数据完整性...');
    
    for (int i = 0; i < materials.length; i++) {
      final materialRow = materials[i];
      final description = materialRow.material.description.trim();
      final images = materialRow.images;
      
      print('  验证材料行 $i: 描述="$description", 图片数量=${images.length}');
      
      // 检查描述是否为空
      if (description.isEmpty) {
        print('  错误：材料行 $i 描述为空');
        return false;
      }
      
      // 检查图片数据完整性
        for (int j = 0; j < images.length; j++) {
          final image = images[j];
          // 避免打印二进制长度，改为打印文件大小和原始名称
          print('    图片 $j: ID=${image.id}, 类型=${image.imageType}, 大小=${image.fileSize}, 名称=${image.originalName}');

          if (image.id == null || image.id == 0) {
          // 新图片：检查是否有文件路径
          if (image.originalName == null || image.originalName!.isEmpty) {
            print('    错误：材料行 $i 的图片 $j 缺少文件路径信息');
            return false;
          }
          
          print('    新图片: 文件路径=${image.originalName}');
          
          // 检查文件是否存在
          final file = File(image.originalName!);
          if (!file.existsSync()) {
            print('    警告：材料行 $i 的图片 $j 文件不存在: ${image.originalName}');
            // 这里不返回false，因为可能是临时文件
          } else {
            print('    文件存在，大小: ${(file.lengthSync() / 1024).toStringAsFixed(1)} KB');
          }
        } else {
          print('    现有图片: ID=${image.id}, 文件名=${image.originalName ?? "未知"}');
        }
      }
      
      print('  材料行 $i 验证通过: 描述="$description", 图片数量=${images.length}');
    }
    
    print('表格式材料数据验证完成，数据完整');
    return true;
  }

  /// 获取表格式材料数据的统计信息
  Map<String, dynamic> getTableFormatStats(List<PatientMaterialWithImages> materials) {
    int totalRows = materials.length;
    int totalImages = 0;
    int newImages = 0;
    int existingImages = 0;
    
    for (final row in materials) {
      totalImages += row.images.length;
      
      for (final image in row.images) {
        if (image.id == null || image.id == 0) {
          newImages++;
        } else {
          existingImages++;
        }
      }
    }
    
    return {
      'totalRows': totalRows,
      'totalImages': totalImages,
      'newImages': newImages,
      'existingImages': existingImages,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        
        // 材料输入组件
        MaterialInputWidget(
          key: widget.materialInputKey,
          materials: _materials,
          onMaterialsChanged: onMaterialsChanged,
          isEditing: widget.patient != null,
          patientId: widget.patient?.id,
        ),
      ],
    );
  }
}
