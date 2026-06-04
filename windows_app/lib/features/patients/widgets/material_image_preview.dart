import 'package:flutter/material.dart';
import 'dart:io';
import '../../../models/material_image.dart';
import 'material_image_detail_dialog.dart';

/// 材料图片预览组件
/// 
/// 用于显示材料图片的缩略图预览，支持点击查看详情和删除
class MaterialImagePreview extends StatelessWidget {
  final MaterialImage image;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MaterialImagePreview({
    Key? key,
    required this.image,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildOptimizedImage(),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedImage() {
    // 检查是否是新添加的图片（通过ID和originalName判断）
    if (image.id == null && image.originalName != null && 
        image.originalName!.isNotEmpty && 
        !image.originalName!.startsWith('http') && 
        !image.originalName!.startsWith('file://')) {
      
      // 这是新添加的图片，使用File显示
      final file = File(image.originalName!);
      
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // 图片内容
            Positioned(
              left: 3,
              top: 3,
              right: 3,
              bottom: 3,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
            // 新图片标识 - 右下角
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '新',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // 现有图片：优先显示缩略图，如果没有缩略图才显示原图
    // 检查是否有有效的缩略图
    if (image.hasThumbnail && image.thumbnailData != null && image.thumbnailData!.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // 缩略图内容
            Positioned(
              left: 3,
              top: 3,
              right: 3,
              bottom: 3,
              child: Image.memory(
                image.thumbnailData!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 缩略图显示失败，回退到原图
                  return Image.memory(
                    image.imageData,
                    fit: BoxFit.cover,
                    errorBuilder: (context, fallbackError, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 32,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // 缩略图标识 - 右下角
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '缩',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 没有缩略图，使用原图
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // 原图内容
            Positioned(
              left: 3,
              top: 3,
              right: 3,
              bottom: 3,
              child: Image.memory(
                image.imageData,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
            // 原图标识 - 右下角
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '原',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// 文件图片预览组件
/// 
/// 用于显示新选择的文件图片预览
class MaterialFileImagePreview extends StatelessWidget {
  final File file;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MaterialFileImagePreview({
    Key? key,
    required this.file,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Stack(
                  children: [
                    // 图片内容
                    Positioned(
                      left: 3,
                      top: 3,
                      right: 3,
                      bottom: 3,
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // 缩略图标识 - 右下角
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '缩',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
