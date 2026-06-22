import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../models/patient_material.dart';
import '../../../models/material_image.dart';
import '../../../models/patient_material_with_images.dart';
import '../../../utils/image_compressor.dart';
import '../../../providers/patient_provider.dart';
import '../../../theme/app_theme.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'material_image_detail_dialog.dart';
import 'material_debug_info_dialog.dart';
import 'material_image_preview.dart';
import 'material_input_card.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
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
    final preservedSelectedImages = _selectedImages
        .map((images) => List<File>.from(images))
        .toList();

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
    print('MaterialInputWidget.initState - 材料数量: ${widget.materials.length}');
    _initializeControllers();
    
    // 如果是编辑模式且有患者ID，直接从数据库加载材料数据
    if (widget.isEditing && widget.patientId != null) {
      print('编辑模式，直接从数据库加载材料数据');
      _loadMaterialsFromDatabase();
    }
  }

  @override
  void didUpdateWidget(MaterialInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    print('MaterialInputWidget.didUpdateWidget 被调用');
    print('  旧材料数量: ${oldWidget.materials.length}');
    print('  新材料数量: ${widget.materials.length}');
    print('  当前控制器数量: ${_descriptionControllers.length}');

    if (_shouldRebuildControllersAfterWidgetUpdate(oldWidget)) {
      print('检测到需要重新初始化控制器');
      _initializeControllers();
      return;
    }

    print('材料数据未发生变化或当前状态需要保留，跳过重新初始化');
  }

  bool _shouldRebuildControllersAfterWidgetUpdate(MaterialInputWidget oldWidget) {
    // 用户刚刚新增了行，保留当前编辑态
    if (_descriptionControllers.length > widget.materials.length) {
      print('检测到用户刚刚添加了新行，保持当前状态，不重新初始化');
      print('  控制器数量: ${_descriptionControllers.length}');
      print('  widget.materials数量: ${widget.materials.length}');
      return false;
    }

    // 当前没有控制器，但有数据，直接重建
    if (widget.materials.isNotEmpty && _descriptionControllers.isEmpty) {
      print('检测到材料数据但控制器为空，需要初始化控制器');
      return true;
    }

    // 编辑模式下，不自动触发数据库重载
    if (widget.isEditing && widget.patientId != null) {
      print('编辑模式下保持当前用户输入，不自动重新加载数据库数据');
      return false;
    }

    if (oldWidget.materials.length != widget.materials.length) {
      if (widget.materials.length > oldWidget.materials.length) {
        for (int i = oldWidget.materials.length; i < widget.materials.length; i++) {
          if (widget.materials[i].material.id == null) {
            print('检测到用户添加的新材料行，跳过重新初始化以保持新行');
            return false;
          }
        }

        print('检测到从外部加载的材料数据，需要重新初始化控制器');
        return true;
      }

      print('材料数量减少，重新初始化控制器');
      return true;
    }

    if (!_areMaterialsEqual(oldWidget.materials, widget.materials)) {
      print('材料数据发生变化，重新初始化控制器');
      return true;
    }

    return false;
  }

  // 比较两个材料列表是否相等
  bool _areMaterialsEqual(List<PatientMaterialWithImages> list1, List<PatientMaterialWithImages> list2) {
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
        
        if (image1.id != image2.id ||
            image1.fileSize != image2.fileSize) {
          return false;
        }
      }
    }
    
    return true;
  }

  void _initializeControllers() {
    print('开始初始化材料输入组件控制器...');
    print('  当前控制器数量: ${_descriptionControllers.length}');
    print('  目标材料数量: ${widget.materials.length}');
    
    // 如果控制器数量已经正确，且内容匹配，则不需要重新初始化
    if (_descriptionControllers.length == widget.materials.length) {
      bool needsReinit = false;
      for (int i = 0; i < _descriptionControllers.length; i++) {
        if (i < widget.materials.length) {
          final expectedText = widget.materials[i].material.description;
          final currentText = _descriptionControllers[i].text;
          if (expectedText != currentText) {
            needsReinit = true;
            print('  材料 $i 描述不匹配，需要重新初始化');
            print('    期望: "$expectedText"');
            print('    当前: "$currentText"');
            break;
          }
        }
      }
      
      if (!needsReinit) {
        print('控制器已正确初始化，跳过重新初始化');
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
        if (images[j] is File) {
          safeImages.add(images[j] as File);
        }
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
        print('  保存材料 $i 的有效文本: "$text", ID=${i < _materialIds.length ? _materialIds[i] : null}');
      }
    }
    
    // 保存现有的图片信息，避免丢失从同名患者加载的图片
    final List<List<MaterialImage>> savedExistingImages = [];
    for (int i = 0; i < _existingImages.length; i++) {
      final images = _existingImages[i];
      if (images.isNotEmpty) {
        savedExistingImages.add(List<MaterialImage>.from(images));
        print('  保存材料 $i 的现有图片: ${images.length} 张');
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

    print('初始化材料输入组件 - 材料数量: ${widget.materials.length}');
    print('保存的有效文本数量: ${savedTexts.length}');
    
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
        print('初始化材料 $i: ID=${material.material.id}, 描述=${description}, 图片数量=${existingImages.length}');
      } else if (i < savedTexts.length) {
        // 使用保存的文本内容（新添加的行）
        description = savedTexts[i];
        materialId = i < savedMaterialIds.length ? savedMaterialIds[i] : null;
        print('恢复新添加的材料行 $i: 描述=${description}, ID=$materialId');
      } else {
        // 设置默认描述（仅对新行）
        description = '材料${i + 1}';
        materialId = null;
        print('设置默认材料行 $i: 描述=${description}');
      }
      
      // 恢复保存的现有图片，如果存在的话
      if (i < savedExistingImages.length && savedExistingImages[i].isNotEmpty) {
        existingImages = savedExistingImages[i];
        print('恢复材料 $i 的现有图片: ${existingImages.length} 张');
      }
      
      _descriptionControllers.add(
        TextEditingController(text: description),
      );
      
      // 恢复已选择的图片状态，如果索引存在的话
      if (i < savedSelectedImages.length) {
        _selectedImages.add(List<File>.from(savedSelectedImages[i]));
        print('恢复材料 $i 的已选择图片: ${savedSelectedImages[i].length} 张');
      } else {
        _selectedImages.add(<File>[]);
      }
      
      // 确保正确复制现有图片
      print('复制现有图片: 数量=${existingImages.length}');
      for (int j = 0; j < existingImages.length; j++) {
        final image = existingImages[j];
        print('  图片 $j: ID=${image.id}, 类型=${image.imageType}');
      }
      _existingImages.add(existingImages);
      
      // 记录对应的材料ID
      _materialIds.add(materialId);
    }
    
    print('初始化完成 - 控制器数量: ${_descriptionControllers.length}');
    print('现有图片数组长度: ${_existingImages.length}');
    print('材料ID数组长度: ${_materialIds.length}');
    for (int i = 0; i < _existingImages.length; i++) {
      print('  材料 $i: 图片数量=${_existingImages[i].length}, ID=${i < _materialIds.length ? _materialIds[i] : null}');
    }
    
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
    print('开始添加新材料行...');
    print('添加前 - 控制器数量: ${_descriptionControllers.length}');
    print('添加前 - widget.materials数量: ${widget.materials.length}');
    
    setState(() {
      // 确保所有数组长度一致
      _ensureMaterialStateConsistency();
      
      // 添加新的控制器，设置默认文本
      final newIndex = _descriptionControllers.length;
      final defaultDescription = '材料${newIndex + 1}';
      
      print('添加新材料行 $newIndex: "$defaultDescription"');
      
      _descriptionControllers.add(
        TextEditingController(text: defaultDescription),
      );
      
      _selectedImages.add(<File>[]);
      _existingImages.add(<MaterialImage>[]);
      _materialIds.add(null); // 新材料ID为null
      
      print('添加后 - 控制器数量: ${_descriptionControllers.length}');
      print('添加后 - 选择图片数组长度: ${_selectedImages.length}');
      print('添加后 - 现有图片数组长度: ${_existingImages.length}');
      print('添加后 - 材料ID数组长度: ${_materialIds.length}');
      
      // 验证数组长度一致性
      if (_descriptionControllers.length != _selectedImages.length ||
          _descriptionControllers.length != _existingImages.length ||
          _descriptionControllers.length != _materialIds.length) {
        print('警告：添加材料后数组长度不一致！');
        _ensureMaterialStateConsistency();
      }
    });
    
    // 标记新添加的行，防止被意外覆盖
    _markNewlyAddedRows();
    
    // 延迟通知父组件，确保状态已同步
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        print('延迟通知父组件新材料行已添加');
        _updateMaterials();
      }
    });
  }

  // 标记新添加的行，防止被意外覆盖
  void _markNewlyAddedRows() {
    // 记录新添加的行索引
    final newRowIndices = <int>[];
    for (int i = widget.materials.length; i < _descriptionControllers.length; i++) {
      newRowIndices.add(i);
    }
    
    if (newRowIndices.isNotEmpty) {
      print('标记新添加的材料行: ${newRowIndices.join(', ')}');
      print('这些行将受到保护，不会被意外覆盖');
    } else {
      print('没有检测到新添加的材料行');
    }
  }
  
  // 调试方法：显示当前状态信息
  void debugCurrentState() {
    print('=== MaterialInputWidget 当前状态调试信息 ===');
    print('控制器数量: ${_descriptionControllers.length}');
    print('选择图片数组数量: ${_selectedImages.length}');
    print('现有图片数组数量: ${_existingImages.length}');
    print('widget.materials数量: ${widget.materials.length}');
    print('widget.isEditing: ${widget.isEditing}');
    print('widget.patientId: ${widget.patientId}');
    
    for (int i = 0; i < _descriptionControllers.length; i++) {
      print('材料 $i:');
      print('  描述: "${_descriptionControllers[i].text}"');
      print('  选择图片数量: ${i < _selectedImages.length ? _selectedImages[i].length : 0}');
      print('  现有图片数量: ${i < _existingImages.length ? _existingImages[i].length : 0}');
      
      if (i < widget.materials.length) {
        final material = widget.materials[i];
        print('  widget.materials[$i]: ID=${material.material.id}, 描述="${material.material.description}"');
      } else {
        print('  widget.materials[$i]: 超出范围');
      }
    }
    print('=== 调试信息结束 ===');
  }

  void _removeMaterial(int index) {
    if (index >= 0 && index < _descriptionControllers.length) {
      print('开始删除材料: 索引=$index');
      print('删除前状态:');
      print('  控制器数量: ${_descriptionControllers.length}');
      print('  选择图片数组长度: ${_selectedImages.length}');
      print('  现有图片数组长度: ${_existingImages.length}');
      print('  材料ID数组长度: ${_materialIds.length}');
      
      // 记录要删除的材料信息
      if (index < widget.materials.length) {
        final material = widget.materials[index];
        // 标记材料ID用于后续删除
        if (material.material.id != null) {
          _materialsToDelete.add(material.material.id!);
          // 标记材料下所有已有图片为删除（只标记有 ID 的图片）
          for (final img in material.images) {
            if (img.id != null) {
              _imagesToDelete.add({
                'imageId': img.id!,
                'materialId': material.material.id,
                'fileName': img.originalName ?? '未命名文件',
              });
            }
          }
          print('已标记材料ID=${material.material.id} 及其 ${material.images.where((e) => e.id!=null).length} 张图片为删除');
        }
        print('  要删除的材料: ID=${material.material.id}, 描述="${material.material.description}", 图片数量=${material.images.length}');
      }
      
      // 记录要删除的材料ID（如果有的话）
      int? deletedMaterialId;
      if (index < _materialIds.length) {
        deletedMaterialId = _materialIds[index];
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
            _newImages[i] = Map<String, dynamic>.from(newImg)..['materialIndex'] = currentIndex - 1;
            print('更新新图片索引: 从 $currentIndex 改为 ${currentIndex - 1}');
          } else if (currentIndex == index) {
            // 如果索引等于被删除的索引，标记为删除
            _newImages.removeAt(i);
            i--; // 调整循环索引
            print('移除被删除材料的新图片记录');
          }
        }
      });
      
      print('删除后状态:');
      print('  控制器数量: ${_descriptionControllers.length}');
      print('  选择图片数组长度: ${_selectedImages.length}');
      print('  现有图片数组长度: ${_existingImages.length}');
      print('  材料ID数组长度: ${_materialIds.length}');
      print('  删除的材料ID: $deletedMaterialId');
      
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
          if (file.path != null) {
            // 调用新增图片方法，记录新图片信息
            _addNewImage(materialIndex, file.path!);
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('选择图片失败: $e');
    }
  }

  void _removeSelectedImage(int materialIndex, int imageIndex) {
    if (materialIndex >= 0 && materialIndex < _selectedImages.length && 
        imageIndex >= 0 && imageIndex < _selectedImages[materialIndex].length) {
      setState(() {
        _selectedImages[materialIndex].removeAt(imageIndex);
      });
      _updateMaterials();
    }
  }

  void _removeExistingImage(int materialIndex, int imageIndex) {
    print('标记图片删除: 材料索引=$materialIndex, 图片索引=$imageIndex');
    
    // 验证索引有效性
    if (materialIndex < 0 || materialIndex >= _existingImages.length) {
      print('错误：材料索引超出范围: $materialIndex, _existingImages长度: ${_existingImages.length}');
      return;
    }
    
    if (imageIndex < 0 || imageIndex >= _existingImages[materialIndex].length) {
      print('错误：图片索引超出范围: $imageIndex, 材料 $materialIndex 的图片数量: ${_existingImages[materialIndex].length}');
      return;
    }
    
    final imageToDelete = _existingImages[materialIndex][imageIndex];
    print('要删除的图片信息: ID=${imageToDelete.id}, 材料ID=${imageToDelete.materialId}, 文件名=${imageToDelete.originalName}');
    
    // 如果是数据库中的图片（有ID），记录删除信息
    if (imageToDelete.id != null && imageToDelete.id! > 0) {
      _imagesToDelete.add({
        'imageId': imageToDelete.id!,
        'materialId': imageToDelete.materialId,
        'fileName': imageToDelete.originalName ?? '未知文件',
      });
      print('已标记数据库图片删除: ID=${imageToDelete.id}, 材料ID=${imageToDelete.materialId}, 文件名=${imageToDelete.originalName}');
    } else {
      // 如果是新添加的图片（没有ID），从_newImages中移除对应记录
      final imagePathToRemove = imageToDelete.originalName;
      if (imagePathToRemove != null && imagePathToRemove.isNotEmpty) {
        _newImages.removeWhere((newImg) => 
          newImg['materialIndex'] == materialIndex && 
          newImg['filePath'] == imagePathToRemove
        );
        print('已从_newImages中移除新图片记录: 材料索引=$materialIndex, 文件路径=$imagePathToRemove');
      }
    }
    
    // 从UI中移除图片
    setState(() {
      _existingImages[materialIndex].removeAt(imageIndex);
      print('已从UI中移除图片: 材料 $materialIndex 现在有 ${_existingImages[materialIndex].length} 张图片');
    });
    
    _updateMaterials();
  }

  void _addNewImage(int materialIndex, String filePath) {
    print('添加新图片: 材料索引=$materialIndex, 文件路径=$filePath');
    
    // 验证索引有效性
    if (materialIndex < 0 || materialIndex >= _descriptionControllers.length) {
      print('错误：材料索引超出范围: $materialIndex, 控制器数量: ${_descriptionControllers.length}');
      return;
    }
    
    // 确保数组长度一致
    _ensureMaterialStateConsistency();
    
    final description = _descriptionControllers[materialIndex].text.trim();
    if (description.isNotEmpty) {
      // 记录新图片信息，使用唯一标识符避免重复
      final imageKey = '${materialIndex}_${path.basename(filePath)}_${DateTime.now().millisecondsSinceEpoch}';
      _newImages.add({
        'materialIndex': materialIndex,
        'description': description,
        'filePath': filePath,
        'fileName': path.basename(filePath),
        'imageKey': imageKey, // 添加唯一标识符
      });
      print('已记录新图片: 材料索引=$materialIndex, 描述="$description", 文件名=${path.basename(filePath)}, 唯一标识=$imageKey');
      
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
        
        print('UI更新完成: 材料 $materialIndex 现在有 ${_existingImages[materialIndex].length} 张图片');
      });
      
      // 强制更新材料列表
      _forceUpdateMaterials();
    } else {
      print('警告：材料描述为空，无法添加图片');
    }
  }

  // 强制更新材料列表（忽略变化检测）
  void _forceUpdateMaterials() {
    print('强制更新材料列表');
    _notifyParentWithCurrentMaterials(forceRebuild: true);
  }

  void _updateMaterials() {
    // 取消之前的定时器
    _updateTimer?.cancel();
    
  print('_updateMaterials 被调用 - 当前控制器数量: ${_descriptionControllers.length}');
    
    // 关键修复：直接从控制器获取描述，避免调用materials getter导致的重复
    final currentDescriptions = _descriptionControllers.map((c) => c.text.trim()).toList();
    
    // 检查是否有实际变化
    bool hasChanges = false;
    
    // 比较当前描述列表和之前的描述列表
    if (_lastMaterialsLength != currentDescriptions.length) {
      hasChanges = true;
      print('材料数量发生变化: ${_lastMaterialsLength} -> ${currentDescriptions.length}');
    } else {
      // 检查描述内容是否有变化
      for (int i = 0; i < currentDescriptions.length; i++) {
        if (i < _lastMaterialDescriptions.length) {
          if (_lastMaterialDescriptions[i] != currentDescriptions[i]) {
            hasChanges = true;
            print('材料 $i 描述发生变化: "${_lastMaterialDescriptions[i]}" -> "${currentDescriptions[i]}"');
            break;
          }
        } else {
          hasChanges = true;
          print('新增材料 $i: "${currentDescriptions[i]}"');
          break;
        }
      }
    }
    
    if (!hasChanges) {
      print('没有检测到实际变化，跳过更新通知');
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
        print('执行延迟的材料更新通知');
        print('通知父组件材料变化，材料数量: ${currentDescriptions.length}');
        
        // 关键修复：在编辑模式下，避免频繁调用materials getter
        _notifyParentWithCurrentMaterials();
      }
    });
  }

  void _notifyParentWithCurrentMaterials({bool forceRebuild = false}) {
    if (widget.isEditing || forceRebuild) {
      print('编辑模式下，使用控制器直接构建材料列表');
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
    print('已清除图片删除和新增记录');
  }

  // 获取要删除的材料ID列表（由 manager 在保存时调用）
  List<int> get materialsToDelete => List.from(_materialsToDelete);

  // 新增方法：直接从控制器构建材料列表，避免调用materials getter
  List<PatientMaterialWithImages> _buildMaterialsListFromControllers() {
    final List<PatientMaterialWithImages> result = [];
    
    print('_buildMaterialsListFromControllers 被调用 - 控制器数量: ${_descriptionControllers.length}');
    print('  当前数组状态: 控制器=${_descriptionControllers.length}, 选择图片=${_selectedImages.length}, 现有图片=${_existingImages.length}, 材料ID=${_materialIds.length}');
    
    // 确保数组长度一致
    _ensureMaterialStateConsistency();
    
    for (int i = 0; i < _descriptionControllers.length; i++) {
      final description = _descriptionControllers[i].text.trim();
      print('  处理材料 $i: 描述="${description}", 长度=${description.length}');
      
      PatientMaterial material;
      
      // 仅根据 materialId 进行匹配，确保精确匹配
      PatientMaterialWithImages? matchingMaterial;
      if (i < _materialIds.length && _materialIds[i] != null) {
        final idToMatch = _materialIds[i];
        matchingMaterial = widget.materials.where((m) => m.material.id == idToMatch).firstOrNull;
        print('    通过ID匹配: 查找ID=$idToMatch, 找到=${matchingMaterial != null}');
      }

      if (matchingMaterial != null && matchingMaterial.material.id != null && matchingMaterial.material.id! > 0) {
        // 现有材料，保留ID和患者ID
        final finalDescription = description.isNotEmpty ? description : matchingMaterial.material.description;
        print('    现有材料 $i: ID=${matchingMaterial.material.id}, 使用描述="${finalDescription}"');
        material = matchingMaterial.material.copyWith(
          description: finalDescription,
          updatedAt: DateTime.now(),
        );
        
        // 获取该材料的图片：从原始材料中获取，过滤掉标记删除的
        final materialId = matchingMaterial.material.id!;
        final imagesToKeep = matchingMaterial.images.where((image) {
          final isMarkedForDeletion = _imagesToDelete.any((deleteRecord) => 
            deleteRecord['imageId'] == image.id && deleteRecord['materialId'] == materialId
          );
          if (isMarkedForDeletion) {
            print('      过滤掉标记删除的图片: ID=${image.id}, 文件名=${image.originalName}');
          }
          return !isMarkedForDeletion;
        }).toList();
        
        print('    现有材料 $i 保留图片数量: ${imagesToKeep.length} (原始: ${matchingMaterial.images.length})');
        
        // 添加该材料行的新图片（通过materialIndex匹配）
        final newImagesForThisMaterial = _newImages.where((newImg) => 
          newImg['materialIndex'] == i
        ).toList();
        
        print('    现有材料 $i 从_newImages中找到 ${newImagesForThisMaterial.length} 张新图片');
        
        for (final newImg in newImagesForThisMaterial) {
          final filePath = newImg['filePath'] as String;
          final fileName = newImg['fileName'] as String;
          
          // 检查是否已经存在相同路径的图片，避免重复
          final alreadyExists = imagesToKeep.any((img) => img.originalName == filePath);
          if (!alreadyExists) {
            imagesToKeep.add(MaterialImage(
              materialId: 0,
              imageData: Uint8List(0),
              imageType: 'image/jpeg',
              fileSize: 0,
              originalName: filePath,
              hasThumbnail: false,
            ));
            print('      为现有材料 $i 添加新图片: 文件路径=$filePath, 文件名=$fileName');
          } else {
            print('      跳过重复的新图片: 文件路径=$filePath');
          }
        }
        
        // 添加UI中显示的临时图片（新选择但还未记录到_newImages的）
        if (i < _existingImages.length) {
          int tempImageCount = 0;
          for (final tempImage in _existingImages[i]) {
            if (tempImage.originalName != null && 
                tempImage.originalName!.isNotEmpty && 
                !tempImage.originalName!.startsWith('http') && 
                !tempImage.originalName!.startsWith('file://') &&
                tempImage.id == null) {
              
              // 检查是否已经包含在imagesToKeep中
              final alreadyIncluded = imagesToKeep.any((img) => 
                img.originalName == tempImage.originalName
              );
              
              if (!alreadyIncluded) {
                print('      为现有材料 $i 添加UI中的临时图片: 文件路径=${tempImage.originalName}');
                imagesToKeep.add(tempImage);
                tempImageCount++;
              }
            }
          }
          print('    现有材料 $i 从UI中添加了 $tempImageCount 张临时图片');
        }
        
        print('    现有材料 $i 最终图片总数: ${imagesToKeep.length}');
        
        result.add(PatientMaterialWithImages(
          material: material,
          images: imagesToKeep,
        ));
        
      } else {
        // 新材料，ID 为 null
        final finalDescription = description;
        print('    新材料 $i: 直接使用用户输入="${finalDescription}"');
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
            print('      从_existingImages添加图片: ID=${existingImage.id}, 路径=${existingImage.originalName}');
          }
        }
        
        // 2. 从_newImages中获取该材料行的新图片
        final newImagesForThisMaterial = _newImages.where((newImg) => 
          newImg['materialIndex'] == i
        ).toList();
        
        print('    新材料 $i 从_newImages中找到 ${newImagesForThisMaterial.length} 张新图片');
        
        for (final newImg in newImagesForThisMaterial) {
          final filePath = newImg['filePath'] as String;
          
          // 检查是否已经存在相同路径的图片，避免重复
          final alreadyExists = images.any((img) => img.originalName == filePath);
          if (!alreadyExists) {
            images.add(MaterialImage(
              materialId: 0,
              imageData: Uint8List(0),
              imageType: 'image/jpeg',
              fileSize: 0,
              originalName: filePath,
              hasThumbnail: false,
            ));
            print('      为新材料 $i 添加新图片: 文件路径=$filePath');
          } else {
            print('      跳过重复的新图片: 文件路径=$filePath');
          }
        }
        
        print('    新材料 $i 处理前图片总数: ${images.length}');
        
        // 去重：移除重复的图片（基于路径或ID）
        final uniqueImages = <MaterialImage>[];
        final seenPaths = <String>{};
        
        for (final image in images) {
          String? imagePath;
          if (image.originalName != null && 
              image.originalName!.isNotEmpty && 
              !image.originalName!.startsWith('http') && 
              !image.originalName!.startsWith('file://')) {
            imagePath = image.originalName!;
          } else if (image.id != null) {
            imagePath = 'existing_${image.id}';
          } else {
            // 使用对象哈希作为后备标识
            imagePath = 'obj_${image.hashCode}';
          }
          
          if (imagePath != null && !seenPaths.contains(imagePath)) {
            seenPaths.add(imagePath);
            uniqueImages.add(image);
          } else {
            print('      跳过重复图片: 路径=$imagePath');
          }
        }
        
        images = uniqueImages;
        print('    新材料 $i 去重后图片数量: ${images.length}');
        
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
      
      print('  材料 $i 已添加到结果中: ID=${material.id}, 描述="${material.description}", 图片数量=${result.last.images.length}');
    }
    
    print('_buildMaterialsListFromControllers 返回 ${result.length} 个材料');
    return result;
  }
  
  // 确保材料状态一致性
  void _ensureMaterialStateConsistency() {
    print('检查材料状态一致性...');
    print('  控制器数量: ${_descriptionControllers.length}');
    print('  选择图片数组数量: ${_selectedImages.length}');
    print('  现有图片数组数量: ${_existingImages.length}');
    print('  材料ID数组数量: ${_materialIds.length}');
    
    final targetLength = _descriptionControllers.length;
    
    // 确保所有数组长度一致
    while (_selectedImages.length < targetLength) {
      _selectedImages.add(<File>[]);
      print('  添加空的选择图片数组，索引: ${_selectedImages.length - 1}');
    }
    while (_selectedImages.length > targetLength) {
      _selectedImages.removeLast();
      print('  移除多余的选择图片数组');
    }
    
    while (_existingImages.length < targetLength) {
      _existingImages.add(<MaterialImage>[]);
      print('  添加空的现有图片数组，索引: ${_existingImages.length - 1}');
    }
    while (_existingImages.length > targetLength) {
      _existingImages.removeLast();
      print('  移除多余的现有图片数组');
    }
    
    while (_materialIds.length < targetLength) {
      _materialIds.add(null);
      print('  添加空的材料ID，索引: ${_materialIds.length - 1}');
    }
    while (_materialIds.length > targetLength) {
      _materialIds.removeLast();
      print('  移除多余的材料ID');
    }
    
    print('  状态一致性检查完成，所有数组长度: $targetLength');
    
    // 验证数组长度确实一致
    if (_selectedImages.length != targetLength || 
        _existingImages.length != targetLength || 
        _materialIds.length != targetLength) {
      print('  警告：数组长度仍然不一致！');
      print('    控制器: ${_descriptionControllers.length}');
      print('    选择图片: ${_selectedImages.length}');
      print('    现有图片: ${_existingImages.length}');
      print('    材料ID: ${_materialIds.length}');
    } else {
      print('  所有数组长度已同步');
    }
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
    if (widget.patientId == null) return;
    
    try {
      print('开始从数据库加载材料数据: 患者ID=${widget.patientId}');
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final materials = await patientProvider.getPatientMaterialsWithImages(widget.patientId!);
      
      print('数据库加载完成，材料数量: ${materials.length}');
      for (int i = 0; i < materials.length; i++) {
        final material = materials[i];
        print('  材料 $i: ID=${material.material.id}, 描述=${material.material.description}, 图片数量=${material.images.length}');
        for (int j = 0; j < material.images.length; j++) {
          final image = material.images[j];
          print('    图片 $j: ID=${image.id}, 类型=${image.imageType}');
        }
      }
      
      final preservedRows = _descriptionControllers.length > materials.length
          ? _captureRowsFrom(materials.length)
          : const <_MaterialInputRowState>[];

      if (preservedRows.isNotEmpty) {
        print('检测到用户刚刚添加了新行，合并数据库数据和新行数据');
      } else {
        print('没有新行，直接使用数据库数据重新初始化');
      }

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
      print('从数据库加载材料数据失败: $e');
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
    
    print('materials getter 被调用 - 控制器数量: ${_descriptionControllers.length}');
    
    for (int i = 0; i < _descriptionControllers.length; i++) {
      final description = _descriptionControllers[i].text.trim();
      print('  材料 $i: 描述="${description}", 长度=${description.length}');
      
      // 检查是否是现有材料
      PatientMaterial material;

      // 优先根据行索引记录的 material id 进行匹配（不再使用描述匹配）
      PatientMaterialWithImages? matchingMaterial;
      if (i < _materialIds.length && _materialIds[i] != null) {
        final idToMatch = _materialIds[i];
        matchingMaterial = widget.materials.where((m) => m.material.id == idToMatch).firstOrNull;
      }

      if (matchingMaterial != null && matchingMaterial.material.id != null && matchingMaterial.material.id! > 0) {
        final finalDescription = description.isNotEmpty ? description : matchingMaterial.material.description;
        print('  现有材料 $i: 通过行ID匹配，ID=${matchingMaterial.material.id}, 使用描述="${finalDescription}"');
        material = matchingMaterial.material.copyWith(
          description: finalDescription,
          updatedAt: DateTime.now(),
        );
        result.add(PatientMaterialWithImages(
          material: material,
          images: List<MaterialImage>.from(matchingMaterial.images),
        ));
        if (i < _materialIds.length) {
          _materialIds[i] = matchingMaterial.material.id;
        } else {
          while (_materialIds.length <= i) {
            _materialIds.add(null);
          }
          _materialIds[i] = matchingMaterial.material.id;
        }
      } else {
        final finalDescription = description;
        print('  新材料 $i: 直接使用用户输入="${finalDescription}"');
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
        final newImagesForThisMaterial = _newImages.where((newImg) => 
          newImg['materialIndex'] == i
        ).toList();
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
          print('  为新材料 $i 添加新图片: 文件路径=$filePath');
        }
        result.add(PatientMaterialWithImages(
          material: material,
          images: images,
        ));
      }
      
      print('  材料 $i 已加入到 materials getter 中');
    }
    
    print('materials getter 返回 ${result.length} 个材料');
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

  Widget _buildDebugRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print('MaterialInputWidget.build 被调用');
    print('  widget.materials 数量: ${widget.materials.length}');
    print('  _descriptionControllers 数量: ${_descriptionControllers.length}');
    print('  _selectedImages 数量: ${_selectedImages.length}');
    print('  _existingImages 数量: ${_existingImages.length}');
    
    // 检查状态一致性
    if (_descriptionControllers.length != _selectedImages.length || 
        _descriptionControllers.length != _existingImages.length) {
      print('  警告：状态不一致，正在修复...');
      _ensureMaterialStateConsistency();
    }
    
    for (int i = 0; i < widget.materials.length; i++) {
      final material = widget.materials[i];
      print('  材料 $i: ID=${material.material.id}, 描述=${material.material.description}, 图片数量=${material.images.length}');
      for (int j = 0; j < material.images.length; j++) {
        final image = material.images[j];
        print('    图片 $j: ID=${image.id}, 类型=${image.imageType}');
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 患者材料标题和操作按钮
        Row(
          children: [
            const Icon(Icons.inventory_2, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
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
                backgroundColor: Colors.orange.withOpacity(0.1),
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
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              print('  构建材料卡片 $index');
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
    
    // 添加调试信息（仅打印元数据，避免输出二进制长度）
    print('构建材料卡片 $index:');
    print('  _existingImages长度: ${_existingImages.length}');
    if (index < _existingImages.length) {
      print('  材料 $index 的现有图片数量: ${_existingImages[index].length}');
      for (int j = 0; j < _existingImages[index].length; j++) {
        final image = _existingImages[index][j];
        print('    图片 $j: ID=${image.id}, 类型=${image.imageType}, 大小=${image.fileSize}, 名称=${image.originalName}');
      }
    }
    
    return MaterialInputCard(
      controller: _descriptionControllers[index],
      existingImages: index < _existingImages.length ? _existingImages[index] : [],
      selectedImages: index < _selectedImages.length ? _selectedImages[index] : [],
      onDelete: () => _removeMaterial(index),
      onPickImages: () => _pickImages(index),
      onRemoveExistingImage: (materialIndex, imageIndex) => _removeExistingImage(materialIndex, imageIndex),
      onRemoveSelectedImage: (materialIndex, imageIndex) => _removeSelectedImage(materialIndex, imageIndex),
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
