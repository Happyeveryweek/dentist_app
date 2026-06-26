import 'package:flutter/material.dart';
import 'dart:io';
import '../../../models/material_image.dart';
import 'material_image_preview.dart';

/// 材料输入卡片组件
/// 用于在材料输入界面显示单个材料的输入框和图片预览
class MaterialInputCard extends StatelessWidget {
  final TextEditingController controller;
  final List<MaterialImage> existingImages;
  final List<File> selectedImages;
  final VoidCallback onDelete;
  final VoidCallback onPickImages;
  final Function(int, int) onRemoveExistingImage;
  final Function(int, int) onRemoveSelectedImage;
  final Function(MaterialImage) onShowImageDetail;
  final Function(File) onShowFileImageDetail;

  const MaterialInputCard({
    Key? key,
    required this.controller,
    required this.existingImages,
    required this.selectedImages,
    required this.onDelete,
    required this.onPickImages,
    required this.onRemoveExistingImage,
    required this.onRemoveSelectedImage,
    required this.onShowImageDetail,
    required this.onShowFileImageDetail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: '材料描述',
                      hintText: '请输入材料描述信息',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                        tooltip: '删除材料',
                      ),
                    ),
                    maxLines: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 显示现有图片
            if (existingImages.isNotEmpty) ...[
              Text(
                '现有图片 (${existingImages.length}张):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: existingImages.length,
                  itemBuilder: (context, imageIndex) {
                    return MaterialImagePreview(
                      image: existingImages[imageIndex],
                      onTap: () =>
                          onShowImageDetail(existingImages[imageIndex]),
                      onDelete: () => onRemoveExistingImage(0, imageIndex),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 显示新添加的图片
            if (selectedImages.isNotEmpty) ...[
              Text(
                '新添加的图片 (${selectedImages.length}张):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  itemBuilder: (context, imageIndex) {
                    return MaterialFileImagePreview(
                      file: selectedImages[imageIndex],
                      onTap: () =>
                          onShowFileImageDetail(selectedImages[imageIndex]),
                      onDelete: () => onRemoveSelectedImage(0, imageIndex),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onPickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('选择图片'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
