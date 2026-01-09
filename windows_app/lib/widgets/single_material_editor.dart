import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../providers/patient_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../utils/image_compressor.dart';
import '../widgets/success_toast.dart';

/// 单组材料编辑器
/// 用于添加新材料组或编辑现有材料组
class SingleMaterialEditor extends StatefulWidget {
  final PatientMaterialWithImages? material; // null表示添加，非null表示编辑
  final int patientId;
  final Function(PatientMaterialWithImages) onSave;
  final VoidCallback? onCancel;

  const SingleMaterialEditor({
    Key? key,
    this.material,
    required this.patientId,
    required this.onSave,
    this.onCancel,
  }) : super(key: key);

  @override
  State<SingleMaterialEditor> createState() => _SingleMaterialEditorState();
}

class _SingleMaterialEditorState extends State<SingleMaterialEditor> {
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<MaterialImage> _images = [];
  bool _isLoading = false;
  bool _isSaving = false;
  
  // 记录要删除的图片ID（仅编辑模式）
  final Set<int> _imagesToDelete = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (widget.material != null) {
      // 编辑模式：加载现有数据
      _descriptionController.text = widget.material!.material.description;
      _images = List.from(widget.material!.images);
    }
  }

  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
        });

        for (PlatformFile file in result.files) {
          if (file.path != null) {
            // 创建临时的MaterialImage对象，用于预览
            final materialImage = MaterialImage(
              materialId: 0, // 临时ID
              imageData: Uint8List(0), // 临时数据
              imageType: path.extension(file.path!).toLowerCase().replaceFirst('.', ''),
              fileSize: file.size,
              originalName: file.path!, // 存储文件路径用于后续处理
              hasThumbnail: false,
            );
            
            _images.add(materialImage);
          }
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    final image = _images[index];
    
    setState(() {
      // 如果是现有图片（有ID），记录到删除列表
      if (image.id != null && image.id! > 0) {
        _imagesToDelete.add(image.id!);
      }
      
      _images.removeAt(index);
    });
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少添加一张图片'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      // 创建或更新材料对象
      PatientMaterial material;
      if (widget.material != null) {
        // 编辑模式：更新现有材料
        material = widget.material!.material.copyWith(
          description: _descriptionController.text.trim(),
        );
      } else {
        // 添加模式：创建新材料
        material = PatientMaterial(
          patientId: widget.patientId,
          description: _descriptionController.text.trim(),
          createdAt: DateTime.now(),
        );
      }

      // 保存材料描述
      PatientMaterial savedMaterial;
      if (material.id == null) {
        savedMaterial = await patientProvider.addPatientMaterial(material);
      } else {
        await patientProvider.updatePatientMaterial(material);
        savedMaterial = material;
      }

      // 处理要删除的图片
      for (int imageId in _imagesToDelete) {
        try {
          await patientProvider.deleteMaterialImage(imageId);
        } catch (e) {
          print('删除图片失败: ID=$imageId, 错误=$e');
        }
      }

      // 处理新添加的图片
      List<MaterialImage> finalImages = [];
      
      for (MaterialImage image in _images) {
        if (image.id != null && image.id! > 0) {
          // 现有图片，直接添加到最终列表
          finalImages.add(image);
        } else if (image.originalName != null && 
                   image.originalName!.isNotEmpty && 
                   !image.originalName!.startsWith('http')) {
          // 新图片，需要处理和保存
          try {
            final file = File(image.originalName!);
            if (await file.exists()) {
              // 压缩图片并生成缩略图
              final compressedResult = await ImageCompressor.compressImageFile(file);
              final thumbnailBytes = await ImageCompressor.generateThumbnail(compressedResult.compressedBytes);
              
              final materialImage = MaterialImage(
                materialId: savedMaterial.id!,
                imageData: compressedResult.compressedBytes,
                imageType: compressedResult.imageType,
                fileSize: compressedResult.compressedSize,
                thumbnailData: thumbnailBytes,
                thumbnailSize: thumbnailBytes.length,
                originalName: path.basename(image.originalName!),
                hasThumbnail: true,
              );
              
              final savedImage = await patientProvider.addMaterialImage(materialImage);
              finalImages.add(savedImage);
            }
          } catch (e) {
            print('保存图片失败: ${image.originalName}, 错误=$e');
          }
        }
      }

      // 创建最终的材料对象
      final finalMaterial = PatientMaterialWithImages(
        material: savedMaterial,
        images: finalImages,
      );

      // 调用回调
      widget.onSave(finalMaterial);

      if (mounted) {
        SuccessToastManager.show(
          context, 
          message: widget.material != null ? '材料更新成功' : '材料添加成功',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: DentalColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.material != null ? Icons.edit : Icons.add_photo_alternate,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.material != null ? '编辑患者材料' : '添加患者材料',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // 内容区域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 材料描述输入
                      Text(
                        '材料描述',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: DentalColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: '请输入材料描述，如：口腔检查照片、治疗前后对比等',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: DentalColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入材料描述';
                          }
                          return null;
                        },
                        maxLines: 2,
                      ),

                      const SizedBox(height: 24),

                      // 图片管理区域
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '图片管理',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: DentalColors.onSurface,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _pickImages,
                            icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_photo_alternate, size: 18),
                            label: Text(_isLoading ? '处理中...' : '添加图片'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DentalColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 图片网格
                      Expanded(
                        child: _buildImageGrid(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 底部按钮
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () {
                      if (widget.onCancel != null) {
                        widget.onCancel!();
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveMaterial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DentalColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('保存中...'),
                          ],
                        )
                      : Text(widget.material != null ? '更新' : '保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_images.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无图片',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击上方"添加图片"按钮选择图片',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8, // 从4增加到8，与查看页面保持一致
        crossAxisSpacing: 3, // 从12减少到3
        mainAxisSpacing: 3, // 从12减少到3
        childAspectRatio: 1,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        return _buildImageCard(image, index);
      },
    );
  }

  Widget _buildImageCard(MaterialImage image, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6), // 从8减少到6
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2, // 从4减少到2
            offset: const Offset(0, 1), // 从(0,2)减少到(0,1)
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            // 图片显示 - 调整边距，添加点击放大功能
            Positioned(
              left: 2, // 添加小边距
              top: 2,
              right: 2,
              bottom: 2,
              child: GestureDetector(
                onTap: () => _showImageDetail(image, index),
                child: _buildImageWidget(image),
              ),
            ),

            // 删除按钮 - 调整大小和位置
            Positioned(
              top: 1,
              right: 1,
              child: GestureDetector(
                onTap: () => _removeImage(index),
                child: Container(
                  width: 16, // 从24减少到16
                  height: 16, // 从24减少到16
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 10, // 从16减少到10
                  ),
                ),
              ),
            ),

            // 图片名称显示
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  _getImageDisplayName(image, index),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(MaterialImage image) {
    // 如果是新选择的图片（有文件路径）
    if (image.originalName != null && 
        image.originalName!.isNotEmpty && 
        !image.originalName!.startsWith('http') &&
        (image.id == null || image.id == 0)) {
      
      final file = File(image.originalName!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: Icon(
                Icons.broken_image,
                color: Colors.grey.shade400,
                size: 32,
              ),
            );
          },
        );
      }
    }

    // 如果是现有图片（有缩略图数据）
    if (image.thumbnailData != null && image.thumbnailData!.isNotEmpty) {
      return Image.memory(
        image.thumbnailData!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade400,
              size: 32,
            ),
          );
        },
      );
    }

    // 如果是现有图片（有原图数据）
    if (image.imageData.isNotEmpty) {
      return Image.memory(
        image.imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade400,
              size: 32,
            ),
          );
        },
      );
    }

    // 默认占位符
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image,
        color: Colors.grey.shade400,
        size: 32,
      ),
    );
  }

  // 获取图片显示名称
  String _getImageDisplayName(MaterialImage image, int index) {
    if (image.originalName != null && image.originalName!.isNotEmpty) {
      // 如果是文件路径，提取文件名
      if (image.originalName!.contains('/') || image.originalName!.contains('\\')) {
        return path.basename(image.originalName!);
      }
      return image.originalName!;
    }
    
    return '图片${index + 1}';
  }

  // 显示图片详情
  void _showImageDetail(MaterialImage image, int index) async {
    // 如果是已保存的图片且有ID，重新从数据库加载完整的原图数据
    MaterialImage fullImage = image;
    
    if (image.id != null && image.id! > 0) {
      try {
        print('加载图片详情: ID=${image.id}，重新从数据库获取原图数据');
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        
        // 重新加载完整的图片数据（包含原图）
        final fullImageData = await patientProvider.getMaterialImage(image.id!);
        if (fullImageData != null) {
          fullImage = fullImageData;
          print('成功加载原图数据: 大小=${fullImage.imageData.length} bytes');
        } else {
          print('无法加载原图数据，使用缓存的图片');
        }
      } catch (e) {
        print('加载原图数据失败: $e，使用缓存的图片');
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 1600,
            maxHeight: 1200,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏 - 使用蓝色横条
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getImageDisplayName(fullImage, index),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              
              // 图片内容 - 直接显示原图数据
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: _buildFullSizeImage(fullImage),
                ),
              ),
              
              // 底部信息栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '文件大小: ${(fullImage.fileSize / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        fullImage.imageType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建全尺寸图片
  Widget _buildFullSizeImage(MaterialImage image) {
    // 如果是新选择的图片（有文件路径）
    if (image.originalName != null && 
        image.originalName!.isNotEmpty && 
        !image.originalName!.startsWith('http') &&
        (image.id == null || image.id == 0)) {
      
      final file = File(image.originalName!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        );
      }
    }

    // 如果是现有图片（优先使用原图数据）
    if (image.imageData.isNotEmpty) {
      return Image.memory(
        image.imageData,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    }

    // 如果只有缩略图数据
    if (image.thumbnailData != null && image.thumbnailData!.isNotEmpty) {
      return Image.memory(
        image.thumbnailData!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
    }

    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.grey[400],
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '图片加载失败',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}