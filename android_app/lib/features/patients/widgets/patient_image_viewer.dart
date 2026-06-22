import 'package:flutter/material.dart';
import '../../../utils/datetime_formatter.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:dentist_app/models/material_image.dart';
import 'package:dentist_app/screens/image_detail_screen.dart';
import 'dart:typed_data';

class PatientImageViewer extends StatelessWidget {
  final List<PatientMaterial> materials;
  final List<MaterialImage> images;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const PatientImageViewer({
    Key? key,
    required this.materials,
    required this.images,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  }) : super(key: key);

  String _formatDateTime(dynamic dateTimeValue) {
    try {
      DateTime dateTime;
      if (dateTimeValue is DateTime) {
        dateTime = dateTimeValue;
      } else if (dateTimeValue is String) {
        dateTime = DateTimeFormatter.fromDbString(dateTimeValue);
      } else {
        return '未知时间';
      }
      
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // 如果解析失败，返回原始值
      return dateTimeValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_library,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '患者图片',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 加载状态
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            
            // 错误状态
            else if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '加载图片失败',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton(
                          onPressed: onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('重试'),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            
            // 材料分组显示
            else if (materials.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: materials.map((material) {
                  // 获取该材料对应的图片
                  final materialImages = images.where((img) => img.materialId == material.id).toList();
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 材料描述标题
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description,
                                    color: Theme.of(context).primaryColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      material.description.isNotEmpty 
                                          ? material.description 
                                          : '材料${material.id}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '相关图片(${materialImages.length}张)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // 创建时间
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey.shade600,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '创建时间: ${_formatDateTime(material.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 图片网格
                        if (materialImages.isNotEmpty)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: materialImages.length,
                            itemBuilder: (context, index) {
                              final image = materialImages[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ImageDetailScreen(image: image),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        // 缩略图
                                        Positioned.fill(
                                          child: image.thumbnailData != null && image.thumbnailData!.isNotEmpty
                                              ? Image.memory(
                                                  Uint8List.fromList(image.thumbnailData!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey.shade100,
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey.shade400,
                                                        size: 20,
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Image.memory(
                                                  Uint8List.fromList(image.imageData),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey.shade100,
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey.shade400,
                                                        size: 20,
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                        // 图片类型标识
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              image.imageType.toUpperCase(),
                                              style: const TextStyle(
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
                              );
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Text(
                                '暂无图片',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              )
            
            // 无数据状态
            else
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无患者图片',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
