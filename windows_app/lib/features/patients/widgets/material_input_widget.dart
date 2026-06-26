import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/patient_material.dart';
import '../../../models/material_image.dart';
import '../../../providers/patient_provider.dart';
import '../../../theme/app_theme.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'material_image_detail_dialog.dart';
import 'material_debug_info_dialog.dart';
import 'material_input_card.dart';
import '../../../utils/log_manager.dart';

/// 材料输入组件
///
/// 修复的问题：
/// 1. 材料描述输入框重复内容问题 - 通过优化_updateMaterials方法和控制器初始化逻辑
/// 2. 新添加的材料行被意外覆盖问题 - 通过智能检测和保护新行
/// 3. 频繁的重复更新问题 - 通过缓存机制和变化检测
/// 4. 控制器重复初始化问题 - 通过条件检查和状态比较
class MaterialInputWidget extends StatefulWidget {
  final List<PatientMaterialWithImages> materials;
  final Function(List<PatientMaterialWithImages>) onMaterialsChanged;
  final bool isEditing;
  final int? patientId; // 添加患者ID参数

  const MaterialInputWidget({
    Key? key,
    required this.materials,
    required this.onMaterialsChanged,
    this.isEditing = false,
    this.patientId, // 添加患者ID参数
  }) : super(key: key);

  @override
  State<MaterialInputWidget> createState() => MaterialInputWidgetState();
}

class _MaterialInputRowState {
  final String description;
  final List<File> selectedImages;
  final List<MaterialImage> existingImages;
  final int? materialId;

  const _MaterialInputRowState({
    required this.description,
    required this.selectedImages,
    required this.existingImages,
    required this.materialId,
  });
}

class MaterialInputWidgetState extends State<MaterialInputWidget> {
  final List<TextEditingController> _descriptionControllers = [];
  final List<List<File>> _selectedImages = [];
  final List<List<MaterialImage>> _existingImages = [];
  // 每行对应的材料ID（如果是数据库已有材料则有值，新增行为 null）
  final List<int?> _materialIds = [];

  // 缓存变量，用于跟踪材料变化，避免重复更新
  int _lastMaterialsLength = 0;
  List<String> _lastMaterialDescriptions = [];
  Timer? _updateTimer;

  // 记录要删除的图片信息
  final List<Map<String, dynamic>> _imagesToDelete = [];

  // 记录新添加的图片信息
  final List<Map<String, dynamic>> _newImages = [];

  // 记录要删除的材料ID（用户点击删除行时记录），保存时由 manager 处理
  final List<int> _materialsToDelete = [];

  _MaterialInputRowState _captureRowState(int index) {
    return _MaterialInputRowState(
      description: index < _descriptionControllers.length
          ? _descriptionControllers[index].text
          : '',
      selectedImages: index < _selectedImages.length
          ? List<File>.from(_selectedImages[index])
          : <File>[],
      existingImages: index < _existingImages.length
          ? List<MaterialImage>.from(_existingImages[index])
          : <MaterialImage>[],
      materialId: index < _materialIds.length ? _materialIds[index] : null,
    );
  }

  List<_MaterialInputRowState> _captureRowsFrom(int startIndex) {
    final rows = <_MaterialInputRowState>[];
    for (int i = startIndex; i < _descriptionControllers.length; i++) {
      rows.add(_captureRowState(i));
    }
    return rows;
  }

  void _rebuildStateFromMaterials(
    List<PatientMaterialWithImages> materials, {
    List<_MaterialInputRowState> preservedRows = const [],
  }) {
    final preservedSelectedImages =
        _selectedImages.map((images) => List<File>.from(images)).toList();

    for (final controller in _descriptionControllers) {
      controller.dispose();
    }
    _descriptionControllers.clear();
    _selectedImages.clear();
    _existingImages.clear();
    _materialIds.clear();

    for (int i = 0; i < materials.length; i++) {
      final material = materials[i];
      _descriptionControllers.add(
        TextEditingController(text: material.material.description),
      );
      _selectedImages.add(
        i < preservedSelectedImages.length
            ? List<File>.from(preservedSelectedImages[i])
            : <File>[],
      );
      _existingImages.add(List<MaterialImage>.from(material.images));
      _materialIds.add(material.material.id);
    }

    for (int i = 0; i < preservedRows.length; i++) {
      final row = preservedRows[i];
      _descriptionControllers.add(
        TextEditingController(
          text: row.description.isNotEmpty
              ? row.description
              : '材料${materials.length + i + 1}',
        ),
      );
      _selectedImages.add(List<File>.from(row.selectedImages));
      _existingImages.add(List<MaterialImage>.from(row.existingImages));
      _materialIds.add(row.materialId);
    }

    _ensureMaterialStateConsistency();
  }

  @override
  void initState() {
    super.initState();

    _initializeControllers();

    // 如果是编辑模式且有患者ID，直接从数据库加载材料数据
    if (widget.isEditing && widget.patientId != null) {
      _loadMaterialsFromDatabase();
    }
  }

  @override
  void didUpdateWidget(MaterialInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_shouldRebuildControllersAfterWidgetUpdate(oldWidget)) {
      _initializeControllers();
      return;
    }
  }

  bool _shouldRebuildControllersAfterWidgetUpdate(
      MaterialInputWidget oldWidget) {
    // 用户刚刚新增了行，保留当前编辑态
    if (_descriptionControllers.length > widget.materials.length) {
      return false;
    }

    // 当前没有控制器，但有数据，直接重建
    if (widget.materials.isNotEmpty && _descriptionControllers.isEmpty) {
      return true;
    }

    // 编辑模式下，不自动触发数据库重载
    if (widget.isEditing && widget.patientId != null) {
      return false;
    }

    if (oldWidget.materials.length != widget.materials.length) {
      if (widget.materials.length > oldWidget.materials.length) {
        for (int i = oldWidget.materials.length;
            i < widget.materials.length;
            i++) {
          if (widget.materials[i].material.id == null) {
            return false;
          }
        }

        return true;
      }

      return true;
    }

    if (!_areMaterialsEqual(oldWidget.materials, widget.materials)) {
      return true;
    }

    return false;
  }

  // 比较两个材料列表是否相等
  bool _areMaterialsEqual(List<PatientMaterialWithImages> list1,
      List<PatientMaterialWithImages> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      final material1 = list1[i];
      final material2 = list2[i];

      if (material1.material.id != material2.material.id ||
          material1.material.description != material2.material.description ||
          material1.images.length != material2.images.length) {
        return false;
      }

      // 比较图片 — 使用 fileSize 而不是二进制长度，避免输出大量数据相关信息
      for (int j = 0; j < material1.images.length; j++) {
        final image1 = material1.images[j];
        final image2 = material2.images[j];

        if (image1.id != image2.id || image1.fileSize != image2.fileSize) {
          return false;
        }
      }
    }

    return true;
  }

  void _initializeControllers() {
    // 如果控制器数量已经正确，且内容匹配，则不需要重新初始化
    if (_descriptionControllers.length == widget.materials.length) {
      bool needsReinit = false;
      for (int i = 0; i < _descriptionControllers.length; i++) {
        if (i < widget.materials.length) {
          final expectedText = widget.materials[i].material.description;
          final currentText = _descriptionControllers[i].text;
          if (expectedText != currentText) {
            needsReinit = true;

            break;
          }
        }
      }

      if (!needsReinit) {
        // 确保数组长度一致
        _ensureMaterialStateConsistency();
        return;
      }
    }

    // 保存当前已选择的图片状态，确保类型安全
    final List<List<File>> savedSelectedImages = [];
    for (int i = 0; i < _selectedImages.length; i++) {
      final images = _selectedImages[i];
      final List<File> safeImages = [];
      for (int j = 0; j < images.length; j++) {
        safeImages.add(images[j]);
      }
      savedSelectedImages.add(safeImages);
    }

    // 保存当前控制器的文本内容（仅保存有效的文本）
    final List<String> savedTexts = [];
    final List<int?> savedMaterialIds = [];
    for (int i = 0; i < _descriptionControllers.length; i++) {
      final text = _descriptionControllers[i].text.trim();
      // 保存所有非空文本，包括用户已输入的内容
      if (text.isNotEmpty) {
        savedTexts.add(text);
        // 同时保存对应的材料ID
        if (i < _materialIds.length) {
          savedMaterialIds.add(_materialIds[i]);
        } else {
          savedMaterialIds.add(null);
        }
      }
    }

    // 保存现有的图片信息，避免丢失从同名患者加载的图片
    final List<List<MaterialImage>> savedExistingImages = [];
    for (int i = 0; i < _existingImages.length; i++) {
      final images = _existingImages[i];
      if (images.isNotEmpty) {
        savedExistingImages.add(List<MaterialImage>.from(images));
      } else {
        savedExistingImages.add(<MaterialImage>[]);
      }
    }

    // 清理旧的控制器
    for (var controller in _descriptionControllers) {
      controller.dispose();
    }
    _descriptionControllers.clear();
    _selectedImages.clear();
    _existingImages.clear();
    _materialIds.clear();

    // 确保控制器数量至少等于widget.materials.length
    final targetCount = math.max(widget.materials.length, savedTexts.length);

    for (int i = 0; i < targetCount; i++) {
      String description = '';
      List<MaterialImage> existingImages = <MaterialImage>[];
      int? materialId;

      if (i < widget.materials.length) {
        // 使用widget.materials中的数据
        final material = widget.materials[i];
        description = material.material.description;
        existingImages = List<MaterialImage>.from(material.images);
        materialId = material.material.id;
      } else if (i < savedTexts.length) {
        // 使用保存的文本内容（新添加的行）
        description = savedTexts[i];
        materialId = i < savedMaterialIds.length ? savedMaterialIds[i] : null;
      } else {
        // 设置默认描述（仅对新行）
        description = '材料${i + 1}';
        materialId = null;
      }

      // 恢复保存的现有图片，如果存在的话
      if (i < savedExistingImages.length && savedExistingImages[i].isNotEmpty) {
        existingImages = savedExistingImages[i];
      }

      _descriptionControllers.add(
        TextEditingController(text: description),
      );

      // 恢复已选择的图片状态，如果索引存在的话
      if (i < savedSelectedImages.length) {
        _selectedImages.add(List<File>.from(savedSelectedImages[i]));
      } else {
        _selectedImages.add(<File>[]);
      }

      _existingImages.add(existingImages);

      // 记录对应的材料ID
      _materialIds.add(materialId);
    }

    for (int i = 0; i < _existingImages.length; i++) {}

    // 最后确保数组长度一致
    _ensureMaterialStateConsistency();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    for (var controller in _descriptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNewMaterial() {
    setState(() {
      // 确保所有数组长度一致
      _ensureMaterialStateConsistency();

      // 添加新的控制器，设置默认文本
      final newIndex = _descriptionControllers.length;
      final defaultDescription = '材料${newIndex + 1}';

      _descriptionControllers.add(
        TextEditingController(text: defaultDescription),
      );

      _selectedImages.add(<File>[]);
      _existingImages.add(<MaterialImage>[]);
      _materialIds.add(null); // 新材料ID为null

      // 验证数组长度一致性
      if (_descriptionControllers.length != _selectedImages.length ||
          _descriptionControllers.length != _existingImages.length ||
          _descriptionControllers.length != _materialIds.length) {
        _ensureMaterialStateConsistency();
      }
    });

    // 标记新添加的行，防止被意外覆盖
    _markNewlyAddedRows();

    // 延迟通知父组件，确保状态已同步
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _updateMaterials();
      }
    });
  }

  // 标记新添加的行，防止被意外覆盖
  void _markNewlyAddedRows() {
    // 记录新添加的行索引
    final newRowIndices = <int>[];
    for (int i = widget.materials.length;
        i < _descriptionControllers.length;
        i++) {
      newRowIndices.add(i);
    }

    if (newRowIndices.isNotEmpty) {
    } else {}
  }

  // 调试方法：显示当前状态信息
  void debugCurrentState() {
    // 临时调试方法，当前无操作
  }

  void _removeMaterial(int index) {
    if (index >= 0 && index < _descriptionControllers.length) {
      // 记录要删除的材料信息
      if (index < widget.materials.length) {
        final material = widget.materials[index];
        // 标记材料ID用于后续删除
        final materialId = material.material.id;
        if (materialId != null) {
          _materialsToDelete.add(materialId);
          // 标记材料下所有已有图片为删除（只标记有 ID 的图片）
          for (final img in material.images) {
            final imageId = img.id;
            if (imageId != null) {
              _imagesToDelete.add({
                'imageId': imageId,
                'materialId': materialId,
                'fileName': img.originalName ?? '未命名文件',
              });
            }
          }
        }
      }

      setState(() {
        // 删除控制器
        _descriptionControllers[index].dispose();
        _descriptionControllers.removeAt(index);

        // 删除对应的图片数组
        if (index < _selectedImages.length) {
          _selectedImages.removeAt(index);
        }
        if (index < _existingImages.length) {
          _existingImages.removeAt(index);
        }
        if (index < _materialIds.length) {
          _materialIds.removeAt(index);
        }

        // 确保所有数组长度一致
        _ensureMaterialStateConsistency();

        // 更新 _newImages 中的 materialIndex，因为删除后索引会发生变化
        for (int i = 0; i < _newImages.length; i++) {
          final newImg = _newImages[i];
          final currentIndex = newImg['materialIndex'] as int;
          if (currentIndex > index) {
            // 如果索引大于被删除的索引，需要减1
            _newImages[i] = Map<String, dynamic>.from(newImg)
              ..['materialIndex'] = currentIndex - 1;
          } else if (currentIndex == index) {
            // 如果索引等于被删除的索引，标记为删除
            _newImages.removeAt(i);
            i--; // 调整循环索引
          }
        }
      });

      _updateMaterials();
    }
  }

  Future<void> _pickImages(int materialIndex) async {
    if (materialIndex < 0 || materialIndex >= _selectedImages.length) {
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
      );

      if (result != null) {
        for (var file in result.files) {
          final filePath = file.path;
          if (filePath != null) {
            // 调用新增图片方法，记录新图片信息
            _addNewImage(materialIndex, filePath);
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('选择图片失败: $e');
    }
  }

  void _removeSelectedImage(int materialIndex, int imageIndex) {
    if (materialIndex >= 0 &&
        materialIndex < _selectedImages.length &&
        imageIndex >= 0 &&
        imageIndex < _selectedImages[materialIndex].length) {
      setState(() {
        _selectedImages[materialIndex].removeAt(imageIndex);
      });
      _updateMaterials();
    }
  }

  void _removeExistingImage(int materialIndex, int imageIndex) {
    // 验证索引有效性
    if (materialIndex < 0 || materialIndex >= _existingImages.length) {
      LogManager.e('MaterialInputWidget',
          '错误：材料索引超出范围: $materialIndex, _existingImages长度: ${_existingImages.length}');
      return;
    }

    if (imageIndex < 0 || imageIndex >= _existingImages[materialIndex].length) {
      LogManager.e('MaterialInputWidget',
          '错误：图片索引超出范围: $imageIndex, 材料 $materialIndex 的图片数量: ${_existingImages[materialIndex].length}');
      return;
    }

    final imageToDelete = _existingImages[materialIndex][imageIndex];
    final imageToDeleteId = imageToDelete.id;

    // 如果是数据库中的图片（有ID），记录删除信息
    if (imageToDeleteId != null && imageToDeleteId > 0) {
      _imagesToDelete.add({
        'imageId': imageToDeleteId,
        'materialId': imageToDelete.materialId,
        'fileName': imageToDelete.originalName ?? '未知文件',
      });
    } else {
      // 如果是新添加的图片（没有ID），从_newImages中移除对应记录
      final imagePathToRemove = imageToDelete.originalName;
      if (imagePathToRemove != null && imagePathToRemove.isNotEmpty) {
        _newImages.removeWhere((newImg) =>
            newImg['materialIndex'] == materialIndex &&
            newImg['filePath'] == imagePathToRemove);
      }
    }

    // 从UI中移除图片
    setState(() {
      _existingImages[materialIndex].removeAt(imageIndex);
    });

    _updateMaterials();
  }

  void _addNewImage(int materialIndex, String filePath) {
    // 验证索引有效性
    if (materialIndex < 0 || materialIndex >= _descriptionControllers.length) {
      LogManager.e('MaterialInputWidget',
          '错误：材料索引超出范围: $materialIndex, 控制器数量: ${_descriptionControllers.length}');
      return;
    }

    // 确保数组长度一致
    _ensureMaterialStateConsistency();

    final description = _descriptionControllers[materialIndex].text.trim();
    if (description.isNotEmpty) {
      // 记录新图片信息，使用唯一标识符避免重复
      final imageKey =
          '${materialIndex}_${path.basename(filePath)}_${DateTime.now().millisecondsSinceEpoch}';
      _newImages.add({
        'materialIndex': materialIndex,
        'description': description,
        'filePath': filePath,
        'fileName': path.basename(filePath),
        'imageKey': imageKey, // 添加唯一标识符
      });

      // 更新UI显示
      setState(() {
        // 确保 _existingImages 数组有足够的长度
        while (_existingImages.length <= materialIndex) {
          _existingImages.add(<MaterialImage>[]);
        }

        // 创建临时的MaterialImage对象用于UI显示
        _existingImages[materialIndex].add(MaterialImage(
          materialId: 0, // 临时ID
          imageData: Uint8List(0), // 临时数据，但不在UI中显示
          imageType: 'image/jpeg',
          fileSize: 0,
          originalName: filePath, // 保存文件路径
          hasThumbnail: false,
        ));
      });

      // 强制更新材料列表
      _forceUpdateMaterials();
    } else {
      LogManager.e('MaterialInputWidget', '警告：材料描述为空，无法添加图片');
    }
  }

  // 强制更新材料列表（忽略变化检测）
  void _forceUpdateMaterials() {
    _notifyParentWithCurrentMaterials(forceRebuild: true);
  }

  void _updateMaterials() {
    // 取消之前的定时器
    _updateTimer?.cancel();

    // 关键修复：直接从控制器获取描述，避免调用materials getter导致的重复
    final currentDescriptions =
        _descriptionControllers.map((c) => c.text.trim()).toList();

    // 检查是否有实际变化
    bool hasChanges = false;

    // 比较当前描述列表和之前的描述列表
    if (_lastMaterialsLength != currentDescriptions.length) {
      hasChanges = true;
    } else {
      // 检查描述内容是否有变化
      for (int i = 0; i < currentDescriptions.length; i++) {
        if (i < _lastMaterialDescriptions.length) {
          if (_lastMaterialDescriptions[i] != currentDescriptions[i]) {
            hasChanges = true;

            break;
          }
        } else {
          hasChanges = true;

          break;
        }
      }
    }

    if (!hasChanges) {
      return;
    }

    // 更新缓存的状态
    _lastMaterialsLength = currentDescriptions.length;
    _lastMaterialDescriptions = List<String>.from(currentDescriptions);

    // 添加调试信息
    debugCurrentState();

    // 设置新的定时器，延迟200ms执行，减少重复调用
    _updateTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        // 关键修复：在编辑模式下，避免频繁调用materials getter
        _notifyParentWithCurrentMaterials();
      }
    });
  }

  void _notifyParentWithCurrentMaterials({bool forceRebuild = false}) {
    if (widget.isEditing || forceRebuild) {
      widget.onMaterialsChanged(_buildMaterialsListFromControllers());
      return;
    }

    widget.onMaterialsChanged(materials);
  }

  // 获取要删除的图片列表
  List<Map<String, dynamic>> get imagesToDelete => List.from(_imagesToDelete);

  // 获取新添加的图片列表
  List<Map<String, dynamic>> get newImages => List.from(_newImages);

  // 清除删除记录（在保存成功后调用）
  void clearDeleteRecords() {
    _imagesToDelete.clear();
    _newImages.clear();
    _materialsToDelete.clear();
  }

  // 获取要删除的材料ID列表（由 manager 在保存时调用）
  List<int> get materialsToDelete => List.from(_materialsToDelete);

  // 新增方法：直接从控制器构建材料列表，避免调用materials getter
  List<PatientMaterialWithImages> _buildMaterialsListFromControllers() {
    final List<PatientMaterialWithImages> result = [];

    // 确保数组长度一致
    _ensureMaterialStateConsistency();

    for (int i = 0; i < _descriptionControllers.length; i++) {
      final description = _descriptionControllers[i].text.trim();

      PatientMaterial material;

      // 仅根据 materialId 进行匹配，确保精确匹配
      PatientMaterialWithImages? matchingMaterial;
      if (i < _materialIds.length && _materialIds[i] != null) {
        final idToMatch = _materialIds[i];
        matchingMaterial = widget.materials
            .where((m) => m.material.id == idToMatch)
            .firstOrNull;
      }

      final matchingMaterialId = matchingMaterial?.material.id;
      if (matchingMaterial != null &&
          matchingMaterialId != null &&
          matchingMaterialId > 0) {
        // 现有材料，保留ID和患者ID
        final finalDescription = description.isNotEmpty
            ? description
            : matchingMaterial.material.description;

        material = matchingMaterial.material.copyWith(
          description: finalDescription,
          updatedAt: DateTime.now(),
        );

        // 获取该材料的图片：从原始材料中获取，过滤掉标记删除的
        final materialId = matchingMaterialId;
        final imagesToKeep = matchingMaterial.images.where((image) {
          final isMarkedForDeletion = _imagesToDelete.any((deleteRecord) =>
              deleteRecord['imageId'] == image.id &&
              deleteRecord['materialId'] == materialId);
          if (isMarkedForDeletion) {}
          return !isMarkedForDeletion;
        }).toList();

        // 添加该材料行的新图片（通过materialIndex匹配）
        final newImagesForThisMaterial =
            _newImages.where((newImg) => newImg['materialIndex'] == i).toList();

        for (final newImg in newImagesForThisMaterial) {
          final filePath = newImg['filePath'] as String;

          // 检查是否已经存在相同路径的图片，避免重复
          final alreadyExists =
              imagesToKeep.any((img) => img.originalName == filePath);
          if (!alreadyExists) {
            imagesToKeep.add(MaterialImage(
              materialId: 0,
              imageData: Uint8List(0),
              imageType: 'image/jpeg',
              fileSize: 0,
              originalName: filePath,
              hasThumbnail: false,
            ));
          } else {}
        }

        // 添加UI中显示的临时图片（新选择但还未记录到_newImages的）
        if (i < _existingImages.length) {
          for (final tempImage in _existingImages[i]) {
            final tempOriginalName = tempImage.originalName;
            if (tempOriginalName != null &&
                tempOriginalName.isNotEmpty &&
                !tempOriginalName.startsWith('http') &&
                !tempOriginalName.startsWith('file://') &&
                tempImage.id == null) {
              // 检查是否已经包含在imagesToKeep中
              final alreadyIncluded = imagesToKeep
                  .any((img) => img.originalName == tempOriginalName);

              if (!alreadyIncluded) {
                imagesToKeep.add(tempImage);
              }
            }
          }
        }

        result.add(PatientMaterialWithImages(
          material: material,
          images: imagesToKeep,
        ));
      } else {
        // 新材料，ID 为 null
        final finalDescription = description;

        material = PatientMaterial(
          id: null,
          patientId: widget.patientId ?? 0,
          description: finalDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 收集该材料行的所有图片
        List<MaterialImage> images = [];

        // 1. 从_existingImages中获取（这些可能是从数据库加载的或UI中临时添加的）
        if (i < _existingImages.length) {
          for (final existingImage in _existingImages[i]) {
            images.add(existingImage);
          }
        }

        // 2. 从_newImages中获取该材料行的新图片
        final newImagesForThisMaterial =
            _newImages.where((newImg) => newImg['materialIndex'] == i).toList();

        for (final newImg in newImagesForThisMaterial) {
          final filePath = newImg['filePath'] as String;

          // 检查是否已经存在相同路径的图片，避免重复
          final alreadyExists =
              images.any((img) => img.originalName == filePath);
          if (!alreadyExists) {
            images.add(MaterialImage(
              materialId: 0,
              imageData: Uint8List(0),
              imageType: 'image/jpeg',
              fileSize: 0,
              originalName: filePath,
              hasThumbnail: false,
            ));
          } else {}
        }

        // 去重：移除重复的图片（基于路径或ID）
        final uniqueImages = <MaterialImage>[];
        final seenPaths = <String>{};

        for (final image in images) {
          String? imagePath;
          final originalName = image.originalName;
          if (originalName != null &&
              originalName.isNotEmpty &&
              !originalName.startsWith('http') &&
              !originalName.startsWith('file://')) {
            imagePath = originalName;
          } else if (image.id != null) {
            imagePath = 'existing_${image.id}';
          } else {
            // 使用对象哈希作为后备标识
            imagePath = 'obj_${image.hashCode}';
          }

          if (!seenPaths.contains(imagePath)) {
            seenPaths.add(imagePath);
            uniqueImages.add(image);
          } else {}
        }

        images = uniqueImages;

        result.add(PatientMaterialWithImages(
          material: material,
          images: images,
        ));

        // 确保_materialIds数组有足够长度并设置为null
        while (_materialIds.length <= i) {
          _materialIds.add(null);
        }
        _materialIds[i] = null;
      }
    }

    return result;
  }

  // 确保材料状态一致性
  void _ensureMaterialStateConsistency() {
    final targetLength = _descriptionControllers.length;

    // 确保所有数组长度一致
    while (_selectedImages.length < targetLength) {
      _selectedImages.add(<File>[]);
    }
    while (_selectedImages.length > targetLength) {
      _selectedImages.removeLast();
    }

    while (_existingImages.length < targetLength) {
      _existingImages.add(<MaterialImage>[]);
    }
    while (_existingImages.length > targetLength) {
      _existingImages.removeLast();
    }

    while (_materialIds.length < targetLength) {
      _materialIds.add(null);
    }
    while (_materialIds.length > targetLength) {
      _materialIds.removeLast();
    }

    // 验证数组长度确实一致
    if (_selectedImages.length != targetLength ||
        _existingImages.length != targetLength ||
        _materialIds.length != targetLength) {
    } else {}
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 直接从数据库加载材料数据
  Future<void> _loadMaterialsFromDatabase() async {
    final patientId = widget.patientId;
    if (patientId == null) return;

    try {
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      final materials = await patientProvider
          .getPatientMaterialsWithImages(patientId);

      final preservedRows = _descriptionControllers.length > materials.length
          ? _captureRowsFrom(materials.length)
          : const <_MaterialInputRowState>[];

      if (preservedRows.isNotEmpty) {
      } else {}

      if (!mounted) {
        return;
      }

      setState(() {
        _rebuildStateFromMaterials(
          materials,
          preservedRows: preservedRows,
        );
      });
    } catch (e) {
      LogManager.e('MaterialInputWidget', '从数据库加载材料数据失败', error: e);
    }
  }

  // 显示调试信息
  void _showDebugInfo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MaterialDebugInfoDialog(
        patientId: widget.patientId,
        materials: widget.materials,
        controllerCount: _descriptionControllers.length,
        existingImagesCount: _existingImages.length,
        selectedImagesCount: _selectedImages.length,
      ),
    );
  }

  // 显示现有图片详情
  void _showImageDetail(MaterialImage image) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MaterialImageDetailDialog(image: image),
    );
  }

  List<List<File>> getSelectedImages() => _selectedImages;
  List<List<MaterialImage>> getExistingImages() => _existingImages;

  // 获取当前材料列表
  List<PatientMaterialWithImages> get materials {
    final List<PatientMaterialWithImages> result = [];

    for (int i = 0; i < _descriptionControllers.length; i++) {
      final description = _descriptionControllers[i].text.trim();

      // 检查是否是现有材料
      PatientMaterial material;

      // 优先根据行索引记录的 material id 进行匹配（不再使用描述匹配）
      PatientMaterialWithImages? matchingMaterial;
      if (i < _materialIds.length && _materialIds[i] != null) {
        final idToMatch = _materialIds[i];
        matchingMaterial = widget.materials
            .where((m) => m.material.id == idToMatch)
            .firstOrNull;
      }

      final matchingMaterialId = matchingMaterial?.material.id;
      if (matchingMaterial != null &&
          matchingMaterialId != null &&
          matchingMaterialId > 0) {
        final finalDescription = description.isNotEmpty
            ? description
            : matchingMaterial.material.description;

        material = matchingMaterial.material.copyWith(
          description: finalDescription,
          updatedAt: DateTime.now(),
        );
        result.add(PatientMaterialWithImages(
          material: material,
          images: List<MaterialImage>.from(matchingMaterial.images),
        ));
        if (i < _materialIds.length) {
          _materialIds[i] = matchingMaterialId;
        } else {
          while (_materialIds.length <= i) {
            _materialIds.add(null);
          }
          _materialIds[i] = matchingMaterialId;
        }
      } else {
        final finalDescription = description;

        material = PatientMaterial(
          id: null,
          patientId: widget.patientId ?? 0,
          description: finalDescription,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        List<MaterialImage> images = [];
        if (i < _existingImages.length) {
          images = List<MaterialImage>.from(_existingImages[i]);
        }
        final newImagesForThisMaterial =
            _newImages.where((newImg) => newImg['materialIndex'] == i).toList();
        for (final newImg in newImagesForThisMaterial) {
          final filePath = newImg['filePath'] as String;
          images.add(MaterialImage(
            materialId: 0,
            imageData: Uint8List(0),
            imageType: 'image/jpeg',
            fileSize: 0,
            originalName: filePath,
            hasThumbnail: false,
          ));
        }
        result.add(PatientMaterialWithImages(
          material: material,
          images: images,
        ));
      }
    }

    return result;
  }

  bool validateInputs() {
    for (int i = 0; i < _descriptionControllers.length; i++) {
      if (_descriptionControllers[i].text.trim().isEmpty) {
        _showErrorSnackBar('请填写第${i + 1}个材料的描述信息');
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // 检查状态一致性
    if (_descriptionControllers.length != _selectedImages.length ||
        _descriptionControllers.length != _existingImages.length) {
      _ensureMaterialStateConsistency();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 患者材料标题和操作按钮
        Row(
          children: [
            const Icon(Icons.inventory_2,
                color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              '患者材料',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const Spacer(),
            // 调试按钮
            TextButton.icon(
              onPressed: _showDebugInfo,
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('调试', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                foregroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 添加材料按钮
            TextButton.icon(
              onPressed: _addNewMaterial,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加材料', style: TextStyle(fontSize: 14)),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_descriptionControllers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无材料信息',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击上方"添加材料"按钮开始添加',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _descriptionControllers.length,
            itemBuilder: (context, index) {
              return _buildMaterialCard(index);
            },
          ),
      ],
    );
  }

  Widget _buildMaterialCard(int index) {
    if (index < 0 || index >= _descriptionControllers.length) {
      return const SizedBox.shrink();
    }

    return MaterialInputCard(
      controller: _descriptionControllers[index],
      existingImages:
          index < _existingImages.length ? _existingImages[index] : [],
      selectedImages:
          index < _selectedImages.length ? _selectedImages[index] : [],
      onDelete: () => _removeMaterial(index),
      onPickImages: () => _pickImages(index),
      onRemoveExistingImage: (materialIndex, imageIndex) =>
          _removeExistingImage(materialIndex, imageIndex),
      onRemoveSelectedImage: (materialIndex, imageIndex) =>
          _removeSelectedImage(materialIndex, imageIndex),
      onShowImageDetail: (image) => _showImageDetail(image),
      onShowFileImageDetail: (file) => _showFileImageDetail(file),
    );
  }

  // 显示文件图片详情
  void _showFileImageDetail(File file) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MaterialFileImageDetailDialog(file: file),
    );
  }
}
