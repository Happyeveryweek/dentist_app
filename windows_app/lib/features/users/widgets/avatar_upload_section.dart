import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:typed_data';
import '../../../theme/app_theme.dart';
import '../../../widgets/dental_icons.dart';

class AvatarUploadSection extends StatelessWidget {
  final String? selectedAvatar;
  final List<int>? uploadedImageData;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Function(String) onAvatarSelected;
  final Function(List<int>, String) onImageUploaded;
  final VoidCallback onImageRemoved;
  final VoidCallback? onPickImage;

  const AvatarUploadSection({
    Key? key,
    required this.selectedAvatar,
    required this.uploadedImageData,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onAvatarSelected,
    required this.onImageUploaded,
    required this.onImageRemoved,
    this.onPickImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageData = uploadedImageData;
    final hasImageData = imageData != null && imageData.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.tokens.border),
        color: context.tokens.cardBackground,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle,
                  color: context.tokens.primaryAccent, size: 20),
              const SizedBox(width: 12),
              const Text(
                '头像设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 头像预览
          if (hasImageData) ...[
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.tokens.primaryAccent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    Uint8List.fromList(imageData),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: context.tokens.border,
                        child: Icon(
                          Icons.error_outline,
                          size: 40,
                          color: context.tokens.textMuted,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 上传按钮
          Row(
            children: [
              Expanded(
                child: DentalGradientButton(
                  text: hasImageData ? '更换头像' : '上传头像',
                  icon: Icons.upload_file,
                  onPressed: onPickImage ?? () {},
                ),
              ),
              if (hasImageData) ...[
                const SizedBox(width: 12),
                DentalGradientButton(
                  text: '删除',
                  icon: Icons.delete,
                  onPressed: onImageRemoved,
                  gradient: AppTheme.dangerGradient,
                ),
              ],
            ],
          ),

          if (!hasImageData) ...[
            const SizedBox(height: 12),
            Text(
              '未上传头像时将使用默认头像',
              style: TextStyle(
                fontSize: 12,
                color: context.tokens.iconMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
