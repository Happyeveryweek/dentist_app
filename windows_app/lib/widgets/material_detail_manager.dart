import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';
import '../widgets/single_material_editor.dart';
import '../utils/permission_utils.dart';

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
      if (widget.patient.doctor == null || widget.patient.doctor!.isEmpty) {
        // 如果患者没有指定医生，所有用户都可以编辑
        return true;
      }
      
      // 检查当前用户的医生是否与患者的医生匹配
      final currentDoctorName = currentUser.doctor?.isNotEmpty == true 
          ? currentUser.doctor! 
          : currentUser.username;
      
      return widget.patient.doctor == currentDoctorName;
    } catch (e) {
      print('检查患者材料编辑权限时出错: $e');
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

    setState(() {
      _isLoading = true;
    });

    try {
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      
      // 使用缩略图模式加载，提升性能
      final materials = await patientProvider.getPatientMaterialsWithThumbnails(widget.patient.id!);
      
      if (mounted) {
        setState(() {
          _materials = materials;
          _isLoading = false;
        });
        
        // 如果是手动刷新，显示成功提示
        if (showSuccessMessage) {
          SuccessToastManager.show(
            context,
            message: '材料数据已刷新',
            duration: const Duration(seconds: 2),
          );
        }
      }
      
      print('成功加载患者材料信息，共 ${materials.length} 个材料');
    } catch (e) {
      print('加载患者材料信息失败: $e');
      if (mounted) {
        setState(() {
          _materials = [];
          _isLoading = false;
        });
        
        SuccessToastManager.showError(
          context,
          message: '加载材料信息失败: $e',
        );
      }
    }
  }

  void _addMaterial() {
    // 检查权限
    if (!_canEditPatientMaterials()) {
      SuccessToastManager.showError(
        context,
        message: '您只能为自己医生的患者添加材料',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SingleMaterialEditor(
        patientId: widget.patient.id!,
        onSave: (material) {
          // 添加成功后刷新列表
          _loadMaterials();
          if (widget.onMaterialsChanged != null) {
            widget.onMaterialsChanged!();
          }
        },
      ),
    );
  }

  void _editMaterial(PatientMaterialWithImages material) {
    // 检查权限
    if (!_canEditPatientMaterials()) {
      SuccessToastManager.showError(
        context,
        message: '您只能编辑自己医生的患者的材料',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SingleMaterialEditor(
        material: material,
        patientId: widget.patient.id!,
        onSave: (updatedMaterial) {
          // 编辑成功后刷新列表
          _loadMaterials();
          if (widget.onMaterialsChanged != null) {
            widget.onMaterialsChanged!();
          }
        },
      ),
    );
  }

  Future<void> _deleteMaterial(PatientMaterialWithImages material) async {
    // 检查权限
    if (!_canDeletePatientMaterials()) {
      SuccessToastManager.showError(
        context,
        message: '您只能删除自己医生的患者的材料',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除材料"${material.material.description}"吗？\n此操作将同时删除该材料的所有图片，且无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && material.material.id != null) {
      try {
        final patientProvider = Provider.of<PatientProvider>(context, listen: false);
        
        // 删除材料（会级联删除相关图片）
        final success = await patientProvider.deletePatientMaterial(material.material.id!);
        
        if (success) {
          // 删除成功后刷新列表
          await _loadMaterials();
          if (widget.onMaterialsChanged != null) {
            widget.onMaterialsChanged!();
          }
          
          if (mounted) {
            DeleteSuccessToastManager.show(context, message: '材料已删除');
          }
        } else {
          throw Exception('删除操作失败');
        }
      } catch (e) {
        if (mounted) {
          SuccessToastManager.showError(
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
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
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
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
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
                        color: AppTheme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '共 ${_materials.length} 项材料',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        if (!_canEditPatientMaterials()) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '只读模式',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
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
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.infoColor.withOpacity(0.3),
                  ),
                ),
                child: IconButton(
                  onPressed: () => _loadMaterials(showSuccessMessage: true),
                  icon: Icon(
                    Icons.refresh,
                    color: AppTheme.infoColor,
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
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _addMaterial,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        '添加材料',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => SuccessToastManager.showError(
                        context,
                        message: '您只能为自己医生的患者添加材料',
                      ),
                      icon: const Icon(Icons.lock, color: Colors.grey),
                      label: const Text(
                        '权限不足',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
            '暂无材料记录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '该患者还没有添加任何材料记录',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          _canEditPatientMaterials()
            ? ElevatedButton.icon(
                onPressed: _addMaterial,
                icon: const Icon(Icons.add),
                label: const Text('添加第一个材料'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            : ElevatedButton.icon(
                onPressed: () => SuccessToastManager.showError(
                  context,
                  message: '您只能为自己医生的患者添加材料',
                ),
                icon: const Icon(Icons.lock),
                label: const Text('权限不足'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList() {
    return ListView.builder(
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final material = _materials[index];
        return _buildMaterialCard(material);
      },
    );
  }

  Widget _buildMaterialCard(PatientMaterialWithImages material) {
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
                _canEditPatientMaterials()
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.warningColor.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _editMaterial(material),
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
                        onPressed: () => SuccessToastManager.showError(
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
                    ),
                const SizedBox(width: 8),
                // 删除按钮 - 根据权限显示不同状态
                _canDeletePatientMaterials()
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _deleteMaterial(material),
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
                        onPressed: () => SuccessToastManager.showError(
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
                    ),
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8, // 从6增加到8，使缩略图更小
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                  childAspectRatio: 1,
                ),
                itemCount: material.images.length,
                itemBuilder: (context, index) {
                  final image = material.images[index];
                  return GestureDetector(
                    onTap: () => _showImageDetail(image),
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
                            // 图片内容 - 调整为更小的边距
                            Positioned(
                              left: 2, // 从3减少到2
                              top: 2,  // 从3减少到2
                              right: 2, // 从3减少到2
                              bottom: 2, // 从3减少到2
                              child: _buildOptimizedThumbnail(image),
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
              ),
            ] else ...[
              Container(
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建优化的缩略图显示组件
  Widget _buildOptimizedThumbnail(MaterialImage image) {
    print('构建优化缩略图: ID=${image.id}, hasValidThumbnail=${image.hasValidThumbnail}');
    
    // 优先显示缩略图，如果没有缩略图才显示原图
    if (image.hasValidThumbnail && image.thumbnailData != null && image.thumbnailData!.isNotEmpty) {
      print('  使用缩略图显示');
      return Image.memory(
        image.thumbnailData!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('缩略图显示错误: $error，回退到原图');
          // 缩略图显示失败，回退到原图
          return _buildFallbackImage(image);
        },
      );
    } else {
      print('  没有缩略图，使用原图显示');
      return _buildFallbackImage(image);
    }
  }

  /// 构建回退图片显示组件
  Widget _buildFallbackImage(MaterialImage image) {
    if (image.imageData.isNotEmpty) {
      return Image.memory(
        image.imageData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('原图也显示失败: $error');
          return Container(
            color: Colors.grey.shade100,
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade400,
              size: 16, // 调整图标大小适应更小的缩略图
            ),
          );
        },
      );
    } else {
      print('图片数据为空');
      return Container(
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: Colors.grey.shade400,
              size: 16,
            ),
            const SizedBox(height: 2),
            Text(
              '无数据',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
  }



  void _showImageDetail(MaterialImage image) async {
    // 如果图片ID存在，重新从数据库加载完整的原图数据
    MaterialImage fullImage = image;
    
    if (image.id != null) {
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
                        fullImage.originalName ?? '图片详情',
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
                  child: fullImage.imageData.isNotEmpty
                      ? Image.memory(
                          fullImage.imageData,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            print('原图显示失败: $error');
                            return Container(
                              width: 400,
                              height: 300,
                              color: Colors.grey.shade100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.grey.shade400,
                                    size: 64,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '图片加载失败',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
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
                          color: Colors.grey.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                color: Colors.grey.shade400,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '图片数据不可用',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
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
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        fullImage.imageType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
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