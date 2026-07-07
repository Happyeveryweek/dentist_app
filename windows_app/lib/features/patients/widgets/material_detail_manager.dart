import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/patient.dart';
import '../../../models/material_image.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/user_provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../widgets/success_toast.dart';
import 'single_material_editor.dart';
import 'material_detail_card.dart';
import 'material_empty_state.dart';
import '../../../utils/log_manager.dart';

/// 详情页材料管理器
/// 在患者详情页的材料标签页中使用
class MaterialDetailManager extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onMaterialsChanged;

  const MaterialDetailManager({
    Key? key,
    required this.patient,
    this.onMaterialsChanged,
  }) : super(key: key);

  @override
  State<MaterialDetailManager> createState() => _MaterialDetailManagerState();
}

class _MaterialDetailManagerState extends State<MaterialDetailManager> {
  List<PatientMaterialWithImages> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  /// 检查当前用户是否可以编辑该患者的材料
  bool _canEditPatientMaterials() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        return false;
      }

      // 管理员拥有所有权限
      if (currentUser.isAdmin) {
        return true;
      }

      // 普通医生只能编辑自己的患者的材料
      // 如果患者没有指定医生，或者当前用户的医生与患者的医生匹配，则允许编辑
      if (widget.patient.doctor?.isNotEmpty != true) {
        // 如果患者没有指定医生，所有用户都可以编辑
        return true;
      }

      // 检查当前用户的医生是否与患者的医生匹配
      final currentUserDoctor = currentUser.doctor;
      final currentDoctorName = currentUserDoctor?.isNotEmpty == true
          ? currentUserDoctor
          : currentUser.username;

      return widget.patient.doctor == currentDoctorName;
    } catch (e) {
      LogManager.e('MaterialDetailManager', '检查患者材料编辑权限时出错', error: e);
      return false;
    }
  }

  /// 检查当前用户是否可以删除该患者的材料
  bool _canDeletePatientMaterials() {
    // 删除权限与编辑权限相同
    return _canEditPatientMaterials();
  }

  Future<void> _loadMaterials({bool showSuccessMessage = false}) async {
    if (!mounted) return;

    final patientId = widget.patient.id;
    if (patientId == null) {
      LogManager.w('MaterialDetailManager', '加载材料时患者ID为空');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);

      // 使用缩略图模式加载，提升性能
      final materials = await patientProvider
          .getPatientMaterialsWithThumbnails(patientId);

      if (mounted) {
        setState(() {
          _materials = materials;
          _isLoading = false;
        });

        // 如果是手动刷新，显示成功提示
        if (showSuccessMessage) {
          AppToastManager.showSuccess(
            context,
            message: '材料数据已刷新',
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      LogManager.e('MaterialDetailManager', '加载患者材料信息失败', error: e);
      if (mounted) {
        setState(() {
          _materials = [];
          _isLoading = false;
        });

        AppToastManager.showError(
          context,
          message: '加载材料信息失败: $e',
        );
      }
    }
  }

  void _addMaterial() {
    // 检查权限
    if (!_canEditPatientMaterials()) {
      AppToastManager.showError(
        context,
        message: '您只能为自己医生的患者添加材料',
      );
      return;
    }

    final patientId = widget.patient.id;
    if (patientId == null) {
      AppToastManager.showError(
        context,
        message: '患者ID为空，无法添加材料',
      );
      return;
    }

    final onMaterialsChanged = widget.onMaterialsChanged;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SingleMaterialEditor(
        patientId: patientId,
        onSave: (material) {
          // 添加成功后刷新列表
          _loadMaterials();
          onMaterialsChanged?.call();
        },
      ),
    );
  }

  void _editMaterial(PatientMaterialWithImages material) {
    // 检查权限
    if (!_canEditPatientMaterials()) {
      AppToastManager.showError(
        context,
        message: '您只能编辑自己医生的患者的材料',
      );
      return;
    }

    final patientId = widget.patient.id;
    if (patientId == null) {
      AppToastManager.showError(
        context,
        message: '患者ID为空，无法编辑材料',
      );
      return;
    }

    final onMaterialsChanged = widget.onMaterialsChanged;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SingleMaterialEditor(
        material: material,
        patientId: patientId,
        onSave: (updatedMaterial) {
          // 编辑成功后刷新列表
          _loadMaterials();
          onMaterialsChanged?.call();
        },
      ),
    );
  }

  Future<void> _deleteMaterial(PatientMaterialWithImages material) async {
    // 检查权限
    if (!_canDeletePatientMaterials()) {
      AppToastManager.showError(
        context,
        message: '您只能删除自己医生的患者的材料',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除材料"${material.material.description}"吗？\n此操作将同时删除该材料的所有图片，且无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.tokens.error,
              foregroundColor: context.colors.onPrimary,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    final materialId = material.material.id;
    if (confirmed == true && materialId != null) {
      try {
        if (!mounted) return;
        final patientProvider =
            Provider.of<PatientProvider>(context, listen: false);
        final onMaterialsChanged = widget.onMaterialsChanged;

        // 删除材料（会级联删除相关图片）
        final success =
            await patientProvider.deletePatientMaterial(materialId);

        if (success) {
          // 删除成功后刷新列表
          await _loadMaterials();
          onMaterialsChanged?.call();

          if (mounted) {
            AppToastManager.showDelete(context, message: '材料已删除');
          }
        } else {
          throw Exception('删除操作失败');
        }
      } catch (e) {
        if (mounted) {
          AppToastManager.showError(
            context,
            message: '删除失败: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部操作栏
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.tokens.cardBackground,
                context.tokens.pageBackground,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.tokens.shadow,
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: context.tokens.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.tokens.primaryAccent,
                      context.tokens.primaryAccent.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library,
                  color: context.colors.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '患者材料',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '共 ${_materials.length} 项材料',
                          style: TextStyle(
                            fontSize: 16,
                            color: context.tokens.textMuted,
                          ),
                        ),
                        if (!_canEditPatientMaterials()) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.tokens.warningContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.tokens.warning,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: context.tokens.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '只读模式',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.tokens.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 刷新按钮
              Container(
                decoration: BoxDecoration(
                  color: context.tokens.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.tokens.info.withValues(alpha: 0.3),
                  ),
                ),
                child: IconButton(
                  onPressed: () => _loadMaterials(showSuccessMessage: true),
                  icon: Icon(
                    Icons.refresh,
                    color: context.tokens.info,
                  ),
                  tooltip: '刷新数据',
                ),
              ),
              const SizedBox(width: 12),
              // 添加材料按钮 - 根据权限显示不同状态
              _canEditPatientMaterials()
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.tokens.primaryAccent,
                            context.tokens.primaryAccent.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: context.tokens.primaryAccent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _addMaterial,
                        icon: Icon(Icons.add, color: context.colors.onPrimary),
                        label: Text(
                          '添加材料',
                          style: TextStyle(
                            color: context.colors.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: context.tokens.disabledBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => AppToastManager.showError(
                          context,
                          message: '您只能为自己医生的患者添加材料',
                        ),
                        icon: Icon(Icons.lock, color: context.tokens.disabledText),
                        label: Text(
                          '权限不足',
                          style: TextStyle(
                            color: context.tokens.disabledText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 材料列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _materials.isEmpty
                  ? _buildEmptyState()
                  : _buildMaterialsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return MaterialEmptyState(
      canEdit: _canEditPatientMaterials(),
      onAddMaterial: _addMaterial,
    );
  }

  Widget _buildMaterialsList() {
    return ListView.builder(
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final material = _materials[index];
        return MaterialDetailCard(
          material: material,
          canEdit: _canEditPatientMaterials(),
          canDelete: _canDeletePatientMaterials(),
          onEdit: () => _editMaterial(material),
          onDelete: () => _deleteMaterial(material),
          onImageTap: (image) => _showImageDetail(image),
        );
      },
    );
  }

  void _showImageDetail(MaterialImage image) async {
    // 如果图片ID存在，重新从数据库加载完整的原图数据
    MaterialImage fullImage = image;
    final imageId = image.id;

    if (imageId != null) {
      try {
        final patientProvider =
            Provider.of<PatientProvider>(context, listen: false);

        // 重新加载完整的图片数据（包含原图）
        final fullImageData = await patientProvider.getMaterialImage(imageId);
        if (fullImageData != null) {
          fullImage = fullImageData;
        } else {
          LogManager.e('MaterialDetailManager', '无法加载原图数据，使用缓存的图片');
        }
      } catch (e) {
        LogManager.e('MaterialDetailManager', '加载原图数据失败，使用缓存的图片', error: e);
      }
    }

    if (!mounted) return;
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
            color: context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.colors.onSurface.withValues(alpha: 0.25),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: context.tokens.primaryHeaderGradient,
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
                        fullImage.originalName ?? '图片详情',
                        style: TextStyle(
                          color: context.colors.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: context.colors.onPrimary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // 图片内容 - 直接显示原图数据
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: fullImage.imageData.isNotEmpty
                      ? Image.memory(
                          fullImage.imageData,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            LogManager.e('MaterialDetailManager', '原图显示失败',
                                error: error);
                            return Container(
                              width: 400,
                              height: 300,
                              color: context.tokens.pageBackground,
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
                                      color: context.tokens.textMuted,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 400,
                          height: 300,
                          color: context.tokens.pageBackground,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                color: context.tokens.iconMuted,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '图片数据不可用',
                                style: TextStyle(
                                  color: context.tokens.textMuted,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              // 底部信息栏
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.tokens.pageBackground,
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
                          color: context.tokens.iconMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '文件大小: ${(fullImage.fileSize / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.tokens.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.tokens.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        fullImage.imageType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
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
      ),
    );
  }
}
