import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient_material_with_images.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../widgets/success_toast.dart';

/// 材料详情卡片组件
/// 用于在患者详情页显示单个材料及其图片
class MaterialDetailCard extends StatelessWidget {
  final PatientMaterialWithImages material;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(dynamic) onImageTap;

  const MaterialDetailCard({
    Key? key,
    required this.material,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.tokens.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: context.tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 材料标题和操作按钮
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: context.tokens.primaryAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.material.description,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(material.material.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // 编辑按钮 - 根据权限显示不同状态
                _buildEditButton(context),
                const SizedBox(width: 8),
                // 删除按钮 - 根据权限显示不同状态
                _buildDeleteButton(context),
              ],
            ),

            const SizedBox(height: 16),

            // 材料图片
            if (material.images.isNotEmpty) ...[
              Text(
                '相关图片 (${material.images.length}张)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildImageGrid(context),
            ] else ...[
              _buildEmptyImagesWidget(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
    return canEdit
        ? Container(
            decoration: BoxDecoration(
              color: context.tokens.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.tokens.warning.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit,
                color: context.tokens.warning,
                size: 18,
              ),
              tooltip: '编辑材料',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: context.tokens.divider,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => AppToastManager.showError(
                context,
                message: '您只能编辑自己医生的患者的材料',
              ),
              icon: Icon(
                Icons.lock,
                color: context.colors.onSurfaceVariant,
                size: 18,
              ),
              tooltip: '权限不足',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return canDelete
        ? Container(
            decoration: BoxDecoration(
              color: context.tokens.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.tokens.error.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete,
                color: context.tokens.error,
                size: 18,
              ),
              tooltip: '删除材料',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: context.tokens.divider,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => AppToastManager.showError(
                context,
                message: '您只能删除自己医生的患者的材料',
              ),
              icon: Icon(
                Icons.lock,
                color: context.colors.onSurfaceVariant,
                size: 18,
              ),
              tooltip: '权限不足',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          );
  }

  Widget _buildImageGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemCount: material.images.length,
      itemBuilder: (context, index) {
        final image = material.images[index];
        return GestureDetector(
          onTap: () => onImageTap(image),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.tokens.divider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: context.tokens.shadow.withValues(alpha: 0.1),
                  blurRadius: 2,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // 图片内容
                  Positioned(
                    left: 2,
                    top: 2,
                    right: 2,
                    bottom: 2,
                    child: _buildThumbnail(context, image),
                  ),
                  // 图片名称显示
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: context.tokens.overlayScrim,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        image.originalName ?? '图片${index + 1}',
                        style: TextStyle(
                          color: context.colors.onPrimary,
                          fontSize: 6,
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
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(BuildContext context, dynamic image) {
    final thumbnailData = image.thumbnailData;
    // 优先显示缩略图，如果没有缩略图才显示原图
    if (image.hasValidThumbnail &&
        thumbnailData != null &&
        thumbnailData.isNotEmpty) {
      return Image.memory(
        thumbnailData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 缩略图显示失败，回退到原图
          return _buildFallbackImage(context, image);
        },
      );
    } else {
      return _buildFallbackImage(context, image);
    }
  }

  Widget _buildFallbackImage(BuildContext context, dynamic image) {
    if (image.imageData.isNotEmpty) {
      return Image.memory(
        image.imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: context.tokens.inputBackground,
            child: Icon(
              Icons.broken_image,
              color: context.tokens.iconMuted,
              size: 16,
            ),
          );
        },
      );
    } else {
      return Container(
        color: context.tokens.inputBackground,
        child: Icon(
          Icons.broken_image,
          color: context.tokens.iconMuted,
          size: 16,
        ),
      );
    }
  }

  Widget _buildEmptyImagesWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.mutedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.tokens.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported,
            color: context.tokens.iconMuted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '暂无相关图片',
            style: TextStyle(
              fontSize: 14,
              color: context.tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
