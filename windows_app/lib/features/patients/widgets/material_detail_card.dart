import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient_material_with_images.dart';
import '../../../theme/app_theme.dart';
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
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
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.material.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(material.material.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildImageGrid(context),
            ] else ...[
              _buildEmptyImagesWidget(),
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
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit,
                color: AppTheme.warningColor,
                size: 18,
              ),
              tooltip: '编辑材料',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => AppToastManager.showError(
                context,
                message: '您只能编辑自己医生的患者的材料',
              ),
              icon: Icon(
                Icons.lock,
                color: Colors.grey[600],
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
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete,
                color: AppTheme.errorColor,
                size: 18,
              ),
              tooltip: '删除材料',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => AppToastManager.showError(
                context,
                message: '您只能删除自己医生的患者的材料',
              ),
              icon: Icon(
                Icons.lock,
                color: Colors.grey[600],
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
              border: Border.all(color: Colors.grey.shade300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                    child: _buildThumbnail(image),
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
                        image.originalName ?? '图片${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
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

  Widget _buildThumbnail(dynamic image) {
    // 优先显示缩略图，如果没有缩略图才显示原图
    if (image.hasValidThumbnail && image.thumbnailData != null && image.thumbnailData!.isNotEmpty) {
      return Image.memory(
        image.thumbnailData!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 缩略图显示失败，回退到原图
          return _buildFallbackImage(image);
        },
      );
    } else {
      return _buildFallbackImage(image);
    }
  }

  Widget _buildFallbackImage(dynamic image) {
    if (image.imageData.isNotEmpty) {
      return Image.memory(
        image.imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade100,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade400,
              size: 16,
            ),
          );
        },
      );
    } else {
      return Container(
        color: Colors.grey.shade100,
        child: Icon(
          Icons.broken_image,
          color: Colors.grey.shade400,
          size: 16,
        ),
      );
    }
  }

  Widget _buildEmptyImagesWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported,
            color: Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '暂无相关图片',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
