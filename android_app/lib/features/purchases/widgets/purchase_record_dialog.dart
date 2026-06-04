import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../providers/purchase_provider.dart';
import '../../../providers/material_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../models/material.dart';
import 'purchase_item_dialog.dart';
import '../../../widgets/toast_manager.dart';
import '../../../widgets/modern_date_picker.dart';
import '../../../utils/datetime_formatter.dart';

class PurchaseRecordDialog extends StatefulWidget {
  final PurchaseRecord? record;
  
  const PurchaseRecordDialog({
    super.key,
    this.record,
  });

  @override
  State<PurchaseRecordDialog> createState() => _PurchaseRecordDialogState();
}

class _PurchaseRecordDialogState extends State<PurchaseRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseDateController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();
  final _doctorController = TextEditingController();
  
  List<PurchaseItem> _purchaseItems = [];
  List<DentalMaterial> _availableMaterials = [];
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.record != null;
    _initializeControllers();
    _loadMaterials();
    if (_isEditing) {
      _loadPurchaseItems();
    }
  }

  void _initializeControllers() {
    if (_isEditing) {
      _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(widget.record!.purchaseDate);
      _supplierController.text = widget.record!.supplier ?? '';
      _notesController.text = widget.record!.notes ?? '';
      _doctorController.text = widget.record!.doctor ?? '';
    } else {
      _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // 设置医生字段的默认值为当前登录用户的医生姓名
      _setDefaultDoctorName();
    }
  }

  /// 设置医生字段的默认值
  void _setDefaultDoctorName() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser != null && currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
        _doctorController.text = currentUser.doctor!;
        print('设置采购医生默认值: ${currentUser.doctor}');
      } else {
        print('当前用户未设置医生姓名，采购医生字段保持为空');
      }
    } catch (e) {
      print('设置采购医生默认值失败: $e');
      // 如果获取失败，保持字段为空
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      final materials = await materialProvider.getAllMaterials();
      setState(() {
        _availableMaterials = materials;
      });
    } catch (e) {
      print('加载材料失败: $e');
    }
  }

  Future<void> _loadPurchaseItems() async {
    if (!_isEditing) return;
    
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      final items = await purchaseProvider.getPurchaseItemsByRecordId(widget.record!.id!);
      setState(() {
        _purchaseItems = items;
      });
    } catch (e) {
      print('加载采购项目失败: $e');
    }
  }

  Future<void> _addPurchaseItem() async {
    final result = await showDialog<PurchaseItem>(
      context: context,
      builder: (context) => const PurchaseItemDialog(),
    );
    
    if (result != null) {
      // ✅ 确保新项目没有ID，避免意外保存
      final newItem = result.copyWith(
        id: null, // 新项目不应该有ID
        purchaseRecordId: null, // 采购记录ID在提交时设置
        createdAt: DateTimeFormatter.nowLocal(),
        updatedAt: DateTimeFormatter.nowLocal(),
      );
      
      setState(() {
        _purchaseItems.add(newItem);
        // 按创建时间降序排序，确保最新的在最前面
        _purchaseItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      
      print('🔄 添加采购项目到内存: ${newItem.materialName}');
      _debugPurchaseItems(); // 调试信息
    }
  }

  Future<void> _editPurchaseItem(PurchaseItem item) async {
    final result = await showDialog<PurchaseItem>(
      context: context,
      builder: (context) => PurchaseItemDialog(item: item, isEditing: true),
    );
    
    if (result != null) {
      setState(() {
        final index = _purchaseItems.indexWhere((element) => element.id == item.id);
        if (index != -1) {
          _purchaseItems[index] = result;
        }
      });
    }
  }

  void _removePurchaseItem(PurchaseItem item) {
    setState(() {
      _purchaseItems.remove(item);
    });
    print('🗑️ 从内存中移除采购项目: ${item.materialName}');
  }

  /// 验证采购项目数据
  bool _validatePurchaseItems() {
    if (_purchaseItems.isEmpty) {
      return false;
    }
    
    for (int i = 0; i < _purchaseItems.length; i++) {
      final item = _purchaseItems[i];
      if (item.materialName.isEmpty || item.quantity <= 0) {
        print('❌ 采购项目 ${i + 1} 数据无效: ${item.materialName}');
        return false;
      }
      
      // 确保新项目没有ID
      if (item.id != null) {
        print('⚠️ 警告：采购项目 ${i + 1} 已有ID: ${item.id}');
      }
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24), // 设置更小的边距让宽度生效
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92, // 从0.96改为0.92
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75, // 高度保持不变
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.add_shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? '编辑采购记录' : '添加采购记录',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            
            // 表单内容 - 减少padding和间距
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12), // 从16减少到12
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 采购日期
                      TextFormField(
                        controller: _purchaseDateController,
                        decoration: const InputDecoration(
                          labelText: '采购日期 *',
                          prefixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // 减少内边距
                        ),
                        readOnly: true,
                        onTap: () async {
                                                     final date = await showDialog<DateTime>(
                             context: context,
                             builder: (BuildContext context) {
                               return ModernDatePickerDialog(
                                 initialDate: _isEditing ? widget.record!.purchaseDate : DateTime.now(),
                                 firstDate: DateTime(2020),
                                 lastDate: DateTime.now().add(const Duration(days: 365)),
                                 title: '选择采购日期',
                               );
                             },
                           );
                          if (date != null) {
                            setState(() {
                              _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(date);
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请选择采购日期';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 12), // 从16减少到12
                      
                      // 供应商
                      TextFormField(
                        controller: _supplierController,
                        decoration: const InputDecoration(
                          labelText: '供应商 *',
                          prefixIcon: Icon(Icons.business, color: Colors.green),
                          border: OutlineInputBorder(),
                          hintText: '请输入供应商名称',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // 减少内边距
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入供应商名称';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 12), // 从16减少到12
                      
                      // 采购医生
                      TextFormField(
                        controller: _doctorController,
                        decoration: const InputDecoration(
                          labelText: '采购医生',
                          prefixIcon: Icon(Icons.person, color: Colors.teal),
                          border: OutlineInputBorder(),
                          hintText: '请输入采购医生姓名（可选）',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 备注
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          prefixIcon: Icon(Icons.note, color: Colors.orange),
                          border: OutlineInputBorder(),
                          hintText: '请输入备注信息（可选）',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // 减少内边距
                        ),
                        maxLines: 2,
                      ),
                      
                      const SizedBox(height: 16), // 从24减少到16
                      
                      // 采购项目明细
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shopping_cart, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '采购项目明细',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: _addPurchaseItem,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('添加项目', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // 减少padding
                                  minimumSize: const Size(0, 28), // 减少最小高度
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8), // 从12减少到8
                          
                          
                          // 表头 - 平衡的布局设计
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // 材料名称列 - 增加空间分配
                                Expanded(
                                  flex: 7, // 从5增加到7，给材料名称更多空间
                                  child: Text(
                                    '材料名称',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                // 数量列
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    '数量',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // 单价列
                                SizedBox(
                                  width: 55,
                                  child: Text(
                                    '单价',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // 总价列
                                SizedBox(
                                  width: 55,
                                  child: Text(
                                    '总价',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // 操作列 - 适中的空间
                                SizedBox(
                                  width: 75, // 适中的宽度
                                  child: Text(
                                    '操作',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 6), // 从8减少到6
                          
                          // 采购项目列表
                          if (_purchaseItems.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16), // 从20减少到16
                              child: Center(
                                child: Text(
                                  '暂无采购项目，点击"添加项目"开始添加',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...(_purchaseItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return _buildPurchaseItemRow(item, index);
                            }).toList()),
                          
                          // 合计行
                          if (_purchaseItems.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8), // 从6增加到8
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 增加padding
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10), // 从8增加到10
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '合计: ${_purchaseItems.length}项',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                      fontSize: 15, // 从14增加到15
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '¥${_calculateTotalAmount()}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                      fontSize: 17, // 从16增加到17
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 底部按钮 - 减少padding
            Container(
              padding: const EdgeInsets.all(12), // 从16减少到12
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savePurchaseRecord,
                      child: Text(_isEditing ? '更新' : '添加'),
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

  Widget _buildPurchaseItemRow(PurchaseItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 适中的padding
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // 材料名称列 - 增加空间分配
          Expanded(
            flex: 7, // 从5增加到7，与表头保持一致
            child: Text(
              item.materialName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12, // 适中的字体大小
              ),
              maxLines: 2, // 允许两行显示
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 数量列
          SizedBox(
            width: 45,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 单价列
          SizedBox(
            width: 55,
            child: Text(
              '¥${item.unitPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 总价列
          SizedBox(
            width: 55,
            child: Text(
              '¥${item.totalPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // 操作列 - 适中但足够大的按钮
          SizedBox(
            width: 75, // 适中的宽度
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 编辑按钮 - 适中但足够大
                GestureDetector(
                  onTap: () => _editPurchaseItem(item),
                  child: Container(
                    padding: const EdgeInsets.all(8), // 适中的点击区域
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 16, // 适中的图标大小
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                
                const SizedBox(width: 6), // 适中的间距
                
                // 删除按钮 - 适中但足够大
                GestureDetector(
                  onTap: () => _removePurchaseItem(item),
                  child: Container(
                    padding: const EdgeInsets.all(8), // 适中的点击区域
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      Icons.delete,
                      size: 16, // 适中的图标大小
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateTotalAmount() {
    final totalAmount = _purchaseItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    return NumberFormat('#,##0.00').format(totalAmount);
  }

  Future<void> _savePurchaseRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_validatePurchaseItems()) {
      SuccessToastManager.showError(
        context,
        message: '请添加至少一个有效的采购项目',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 计算总计
      final totalQuantity = _purchaseItems.fold<int>(0, (sum, item) => sum + item.quantity);
      final totalAmount = _purchaseItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);

      final purchaseRecord = PurchaseRecord(
        id: widget.record?.id,
        purchaseDate: DateTimeFormatter.fromDbString('${_purchaseDateController.text} 00:00:00'),
        totalQuantity: totalQuantity,
        totalAmount: totalAmount,
        supplier: _supplierController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        doctor: _doctorController.text.trim().isEmpty ? null : _doctorController.text.trim(),
        createdAt: _isEditing ? widget.record!.createdAt : DateTimeFormatter.nowLocal(),
        updatedAt: DateTimeFormatter.nowLocal(),
      );

      int? recordId;
      int success;
      
      if (_isEditing) {
        success = await purchaseProvider.updatePurchaseRecord(purchaseRecord);
        recordId = widget.record?.id;
      } else {
        recordId = await purchaseProvider.addPurchaseRecord(purchaseRecord);
        success = recordId ?? 0;
      }

      if (success > 0 && recordId != null) {
        print('🔄 采购记录保存成功，ID: $recordId');
        
        if (_isEditing) {
          // 🔧 编辑模式：智能处理采购项目，避免删除所有项目
          print('🔧 编辑模式：智能处理采购项目...');
          
          // 获取数据库中现有的项目
          final existingItems = await purchaseProvider.getPurchaseItemsByRecordId(recordId!);
          final existingItemsMap = {for (var item in existingItems) item.id: item};
          
          // 处理当前界面中的项目
          for (final currentItem in _purchaseItems) {
            if (currentItem.id == null) {
              // 新增的项目
              print('➕ 新增项目: ${currentItem.materialName}');
              final newItem = PurchaseItem(
                purchaseRecordId: recordId!,
                materialId: currentItem.materialId,
                materialName: currentItem.materialName,
                quantity: currentItem.quantity,
                unitPrice: currentItem.unitPrice,
                totalPrice: currentItem.totalPrice,
                unit: currentItem.unit,
                createdAt: DateTimeFormatter.nowLocal(),
                updatedAt: DateTimeFormatter.nowLocal(),
              );
              await purchaseProvider.addPurchaseItem(newItem);
            } else if (existingItemsMap.containsKey(currentItem.id)) {
              // 可能修改过的现有项目 - 检查是否需要更新
              final existingItem = existingItemsMap[currentItem.id]!;
              bool hasChanged = 
                  existingItem.materialName != currentItem.materialName ||
                  existingItem.quantity != currentItem.quantity ||
                  existingItem.unitPrice != currentItem.unitPrice ||
                  existingItem.totalPrice != currentItem.totalPrice ||
                  existingItem.unit != currentItem.unit ||
                  existingItem.materialId != currentItem.materialId;
                  
              if (hasChanged) {
                print('✏️ 更新项目: ${currentItem.materialName}');
                final updatedItem = PurchaseItem(
                  id: currentItem.id,
                  purchaseRecordId: recordId!,
                  materialId: currentItem.materialId,
                  materialName: currentItem.materialName,
                  quantity: currentItem.quantity,
                  unitPrice: currentItem.unitPrice,
                  totalPrice: currentItem.totalPrice,
                  unit: currentItem.unit,
                  createdAt: existingItem.createdAt, // 保持原有的创建时间
                  updatedAt: DateTimeFormatter.nowLocal(),
                );
                await purchaseProvider.updatePurchaseItem(updatedItem);
              } else {
                print('⏭️ 跳过未修改的项目: ${currentItem.materialName}');
                // 不更新时间，保持原有updatedAt
              }
            }
          }
          
          // 删除界面中已移除的项目
          final currentItemIds = _purchaseItems.where((item) => item.id != null).map((item) => item.id!).toSet();
          for (final existingItem in existingItems) {
            if (!currentItemIds.contains(existingItem.id)) {
              print('🗑️ 删除已移除的项目: ${existingItem.materialName}');
              await purchaseProvider.deletePurchaseItem(existingItem.id!);
            }
          }
          
        } else {
          // 新增模式：添加所有项目
          print('🔄 新增模式：添加所有 ${_purchaseItems.length} 个采购项目...');
          for (final item in _purchaseItems) {
            final purchaseItem = PurchaseItem(
              purchaseRecordId: recordId!,
              materialId: item.materialId,
              materialName: item.materialName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
              unit: item.unit,
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            );
            await purchaseProvider.addPurchaseItem(purchaseItem);
          }
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          SuccessToastManager.show(
            context,
            message: _isEditing ? '采购记录已更新' : '采购记录已添加',
          );
        }
      } else {
        if (mounted) {
          SuccessToastManager.showError(
            context,
            message: '保存失败',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SuccessToastManager.showError(
          context,
          message: '保存失败: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _purchaseDateController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  /// 测试方法：验证采购项目数据
  void _debugPurchaseItems() {
    print('🔍 调试采购项目数据:');
    print('总数量: ${_purchaseItems.length}');
    
    for (int i = 0; i < _purchaseItems.length; i++) {
      final item = _purchaseItems[i];
      print('项目 ${i + 1}:');
      print('  ID: ${item.id}');
      print('  材料名称: ${item.materialName}');
      print('  数量: ${item.quantity}');
      print('  单价: ${item.unitPrice}');
      print('  采购记录ID: ${item.purchaseRecordId}');
      print('  ---');
    }
  }
}
