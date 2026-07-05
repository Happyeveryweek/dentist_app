import 'package:flutter/material.dart';
import 'dart:io';
import '../../../models/material_image.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 图片详情弹窗组件
///
/// 用于显示材料图片的详细信息，支持缩放查看
class MaterialImageDetailDialog extends StatelessWidget {
  final MaterialImage image;
  final File? file;

  const MaterialImageDetailDialog({
    Key? key,
    required this.image,
    this.file,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 1600,
          maxHeight: 1200,
        ),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.tokens.shadow.withValues(alpha: 0.25),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 极简标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.tokens.primaryAccent.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.photo,
                    color: context.colors.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      image.originalName ?? '图片详情',
                      style: TextStyle(
                        color: context.colors.onPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon:
                        Icon(Icons.close, color: context.colors.onPrimary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // 图片内容 - 无边框无边距
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildDetailImage(context),
              ),
            ),

            // 极简底部信息栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.tokens.inputBackground,
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
                        color: context.colors.onSurfaceVariant,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '文件大小: ${(image.fileSize / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.tokens.primaryAccent
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      image.id != null ? 'ID: ${image.id}' : '新图片',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.primaryAccent,
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
    );
  }

  Widget _buildDetailImage(BuildContext context) {
    final localFile = file;
    if (localFile != null) {
      return Image.file(
        localFile,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorContainer(context, '图片加载失败');
        },
      );
    }

    if (image.imageData.isNotEmpty) {
      return Image.memory(
        image.imageData,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorContainer(context, '图片加载失败');
        },
      );
    } else {
      // 如果没有原图数据，尝试使用缩略图
      final thumbnailData = image.thumbnailData;
      if (thumbnailData != null && thumbnailData.isNotEmpty) {
        return Image.memory(
          thumbnailData,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorContainer(context, '图片数据不可用');
          },
        );
      } else {
        return _buildErrorContainer(context, '图片数据不可用');
      }
    }
  }

  Widget _buildErrorContainer(BuildContext context, String message) {
    return Container(
      width: 400,
      height: 300,
      color: context.tokens.inputBackground,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: context.tokens.iconMuted,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// 文件图片详情弹窗组件
///
/// 用于显示本地文件图片的详细信息
class MaterialFileImageDetailDialog extends StatelessWidget {
  final File file;

  const MaterialFileImageDetailDialog({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 1600,
          maxHeight: 1200,
        ),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.tokens.shadow.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
              decoration: BoxDecoration(
                color: context.tokens.primaryAccent.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    color: context.colors.onPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: TextStyle(
                        color: context.colors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.colors.onPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),

            // 图片内容 - 无边框无边距
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 400,
                      height: 300,
                      color: context.tokens.inputBackground,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: context.tokens.iconMuted,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '图片加载失败',
                            style: TextStyle(
                              color: context.colors.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 底部信息栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.tokens.mutedBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open,
                    color: context.colors.onSurfaceVariant,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '文件路径: ${file.path}',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
