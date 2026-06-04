import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/purchase_item.dart';
import '../../../models/material.dart';
import '../../../providers/material_provider.dart';
import '../../../widgets/toast_manager.dart';
import '../../../utils/datetime_formatter.dart';

class PurchaseItemDialog extends StatefulWidget {
  final PurchaseItem? item;
  final bool isEditing;
  final int? purchaseRecordId; // ✅ 新增：采购记录ID参数
  
  const PurchaseItemDialog({
    super.key,
    this.item,
    this.isEditing = false,
    this.purchaseRecordId, // ✅ 新增：采购记录ID参数
  });

  @override
  State<PurchaseItemDialog> createState() => _PurchaseItemDialogState();
}

class _PurchaseItemDialogState extends State<PurchaseItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _materialNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _unitController = TextEditingController();
  final _unitPriceFocusNode = FocusNode();
  
  // 常用单位选项
  final List<String> _commonUnits = ['个', '件', '盒', '包', '瓶', '支', '副', '套', '米', '千克'];
  
  // 材料库数据
  List<DentalMaterial> _availableMaterials = [];
  bool _isLoadingMaterials = false;
  int? _selectedMaterialId; // 添加选中的材料ID

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadMaterials();
    _setupFocusNodeAndController(_unitPriceFocusNode, _unitPriceController, '0.00');
  }

  void _initializeControllers() {
    if (widget.isEditing && widget.item != null) {
      _materialNameController.text = widget.item!.materialName;
      _quantityController.text = widget.item!.quantity.toString();
      _unitPriceController.text = widget.item!.unitPrice.toString();
      _unitController.text = widget.item!.unit ?? '个';
      _selectedMaterialId = widget.item!.materialId; // 设置材料ID
    } else {
      _quantityController.text = '1';
      _unitPriceController.text = '0.00';
      _unitController.text = '个';
    }
  }

  // 加载材料库数据
  Future<void> _loadMaterials() async {
    setState(() {
      _isLoadingMaterials = true;
    });

    try {
      // 从MaterialProvider获取真实材料数据
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      final materials = await materialProvider.getAllMaterials();
      
      setState(() {
        _availableMaterials = materials;
      });
    } catch (e) {
      print('加载材料库失败: $e');
      // 如果加载失败，显示错误提示
      if (mounted) {
        SuccessToastManager.showError(
          context,
          message: '加载材料库失败: $e',
        );
      }
    } finally {
      setState(() {
        _isLoadingMaterials = false;
      });
    }
  }

  // 显示材料搜索对话框（改为在弹窗内部通过 MaterialProvider 获取数据）
  Future<void> _showMaterialSearchDialog() async {
    final result = await showDialog<DentalMaterial>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3), // 设置半透明背景
      barrierDismissible: true, // 允许点击背景关闭
      builder: (context) => _MaterialSearchDialog(),
    );

    if (result != null) {
      setState(() {
        _materialNameController.text = result.materialName;
        _unitController.text = result.unit;
        _unitPriceController.text = result.defaultPrice.toStringAsFixed(2);
        _selectedMaterialId = result.id; // 更新选中的材料ID
      });
    }
  }


  void _setupFocusNodeAndController(FocusNode focusNode, TextEditingController controller, String defaultValue) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (controller.text == defaultValue) {
          controller.clear();
        }
      } else {
        if (controller.text.isEmpty) {
          controller.text = defaultValue;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white, // 明确设置背景色
      elevation: 8, // 增加阴影效果
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40), // 设置边距
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.6, // 从0.7减少到0.6
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    widget.isEditing ? Icons.edit : Icons.add_shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isEditing ? '编辑采购项目' : '添加采购项目',
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
            
            // 表单内容 - 减少padding和间距，让单位填写框紧贴底部按钮
            Padding(
              padding: const EdgeInsets.all(8), // 从12减少到8
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 让内容紧凑排列
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 材料名称
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _materialNameController,
                            decoration: const InputDecoration(
                              labelText: '材料名称 *',
                              prefixIcon: Icon(Icons.inventory, color: Colors.blue),
                              border: OutlineInputBorder(),
                              hintText: '请输入材料名称',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 减少垂直padding
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入材料名称';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _showMaterialSearchDialog,
                          icon: const Icon(Icons.search, color: Colors.blue),
                          tooltip: '从材料库搜索',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            padding: const EdgeInsets.all(8), // 进一步减少padding
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8), // 从12减少到8
                    
                    // 数量和单价行
                    Row(
                      children: [
                        // 数量
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: '数量 *',
                              prefixIcon: Icon(Icons.format_list_numbered, color: Colors.green),
                              border: OutlineInputBorder(),
                              hintText: '1',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 进一步减少垂直padding
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final quantity = int.tryParse(value ?? '');
                              if (quantity == null || quantity <= 0) {
                                return '数量必须大于0';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // 单价
                        Expanded(
                          child: TextFormField(
                            controller: _unitPriceController,
                            focusNode: _unitPriceFocusNode,
                            decoration: const InputDecoration(
                              labelText: '单价 *',
                              prefixIcon: Icon(Icons.attach_money, color: Colors.orange),
                              border: OutlineInputBorder(),
                              hintText: '0.00',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 进一步减少垂直padding
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              final price = double.tryParse(value ?? '');
                              if (price == null || price < 0) {
                                return '单价不能为负数';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8), // 从12减少到8
                    
                    // 单位选择 - 紧贴底部按钮
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _unitController,
                            decoration: const InputDecoration(
                              labelText: '单位',
                              prefixIcon: Icon(Icons.category, color: Colors.purple),
                              border: OutlineInputBorder(),
                              hintText: '个',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 减少垂直padding
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入单位';
                              }
                              return null;
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // 常用单位快速选择
                        PopupMenuButton<String>(
                          onSelected: (String unit) {
                            setState(() {
                              _unitController.text = unit;
                            });
                          },
                          itemBuilder: (BuildContext context) {
                            return _commonUnits.map((String unit) {
                              return PopupMenuItem<String>(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // 减少水平padding
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    
                                         // 预览信息 - 只在有内容时显示，减少空白
                     if (_materialNameController.text.isNotEmpty) ...[
                       const SizedBox(height: 8), // 减少间距
                       
                       // ✅ 显示临时ID提示（如果是新创建的采购记录）
                       if (widget.purchaseRecordId == 0 && !widget.isEditing) ...[
                         Container(
                           padding: const EdgeInsets.all(6),
                           decoration: BoxDecoration(
                             color: Colors.orange[50],
                             borderRadius: BorderRadius.circular(6),
                             border: Border.all(color: Colors.orange[200]!),
                           ),
                           child: Row(
                             children: [
                               Icon(Icons.info_outline, color: Colors.orange[600], size: 14),
                               const SizedBox(width: 6),
                               Expanded(
                                 child: Text(
                                   '这是新采购记录的项目，保存采购记录时会自动分配ID',
                                   style: TextStyle(
                                     color: Colors.orange[700],
                                     fontSize: 11,
                                   ),
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(height: 6),
                       ],
                       
                       Container(
                         padding: const EdgeInsets.all(8), // 从12减少到8
                         decoration: BoxDecoration(
                           color: Colors.blue[50],
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.blue[200]!),
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               '预览信息',
                               style: TextStyle(
                                 color: Colors.blue[700],
                                 fontWeight: FontWeight.bold,
                                 fontSize: 13, // 从14减少到13
                               ),
                             ),
                            const SizedBox(height: 4), // 从6减少到4
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '材料名称: ${_materialNameController.text}',
                                  style: const TextStyle(fontSize: 13), // 从14减少到13
                                ),
                                Text(
                                  '数量: ${_quantityController.text}',
                                  style: const TextStyle(fontSize: 13), // 从14减少到13
                                ),
                              ],
                            ),
                            const SizedBox(height: 3), // 从4减少到3
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '单价: ¥${_unitPriceController.text}',
                                  style: const TextStyle(fontSize: 13), // 从14减少到13
                                ),
                                Text(
                                  '单位: ${_unitController.text}',
                                  style: const TextStyle(fontSize: 13), // 从14减少到13
                                ),
                              ],
                            ),
                            const SizedBox(height: 4), // 从6减少到4
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6), // 从8减少到6
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '总价: ¥${_calculateTotalPrice()}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, // 从16减少到14
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // 底部按钮 - 紧贴表单内容，减少padding
            Container(
              padding: const EdgeInsets.all(8), // 从12减少到8
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
                      onPressed: _savePurchaseItem,
                      child: Text(widget.isEditing ? '更新' : '添加'),
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

  String _calculateTotalPrice() {
    try {
      final quantity = int.tryParse(_quantityController.text) ?? 0;
      final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
      final totalPrice = quantity * unitPrice;
      return NumberFormat('#,##0.00').format(totalPrice);
    } catch (e) {
      return '0.00';
    }
  }

  void _savePurchaseItem() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final materialName = _materialNameController.text.trim();
    final quantity = int.parse(_quantityController.text);
    final unitPrice = double.parse(_unitPriceController.text);
    final unit = _unitController.text.trim();
    final totalPrice = quantity * unitPrice;

    // ✅ 对于新创建的采购记录，允许使用临时ID 0
    // 在保存采购记录时会重新设置正确的ID
    final purchaseRecordId = widget.purchaseRecordId ?? 
                            widget.item?.purchaseRecordId ?? 
                            0;

    // ✅ 只有在编辑现有项目且没有有效ID时才报错
    if (widget.isEditing && purchaseRecordId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('错误：缺少采购记录ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final purchaseItem = PurchaseItem(
      id: widget.item?.id,
      purchaseRecordId: purchaseRecordId, // ✅ 使用正确的采购记录ID
      materialId: _selectedMaterialId,
      materialName: materialName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      unit: unit,
      createdAt: widget.item?.createdAt ?? DateTimeFormatter.nowLocal(),
      updatedAt: DateTimeFormatter.nowLocal(),
    );

    Navigator.of(context).pop(purchaseItem);
  }

  @override
  void dispose() {
    _materialNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _unitController.dispose();
    super.dispose();
  }
}

// 材料搜索对话框（内部通过 MaterialProvider 获取数据以使用数据源 + 缓存 + 动态连接）
class _MaterialSearchDialog extends StatefulWidget {
  const _MaterialSearchDialog();

  @override
  State<_MaterialSearchDialog> createState() => _MaterialSearchDialogState();
}

class _MaterialSearchDialogState extends State<_MaterialSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<DentalMaterial> _filteredMaterials = [];
  List<DentalMaterial> _allMaterials = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      final materials = await materialProvider.getAllMaterials();
      _allMaterials = materials;
      _filteredMaterials = List.from(_allMaterials);
    } catch (e) {
      print('加载材料失败: $e');
      _allMaterials = [];
      _filteredMaterials = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterMaterials(String query) async {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredMaterials = List.from(_allMaterials);
      });
      return;
    }

    try {
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      // 使用 provider 的 searchMaterials（会走 data source + 缓存）
      final results = await materialProvider.searchMaterials(_searchQuery);
      setState(() {
        _filteredMaterials = results;
      });
    } catch (e) {
      print('搜索材料失败: $e');
      // 本地过滤作为回退
      setState(() {
        _filteredMaterials = _allMaterials.where((DentalMaterial material) {
          final nameMatch = material.materialName.toLowerCase().contains(_searchQuery.toLowerCase());
          final codeMatch = material.materialCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
          final supplierMatch = material.supplier?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
          return nameMatch || codeMatch || supplierMatch;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.6, // 从0.7减少到0.6
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
                  const Icon(Icons.search, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '选择材料',
                    style: TextStyle(
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
            
            // 搜索框 - 减少margin
            Container(
              margin: const EdgeInsets.all(12), // 从16减少到12
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '搜索材料',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[500]!, width: 2),
                  ),
                  hintText: '输入材料名称、编码或供应商',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 减少垂直padding
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _filterMaterials('');
                          },
                        )
                      : null,
                ),
                onChanged: _filterMaterials,
                autofocus: true, // 自动聚焦到搜索框
              ),
            ),
            
                  // 搜索结果统计 - 减少margin
            if (_searchQuery.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12), // 从16减少到12
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // 减少垂直padding
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '找到 ${_filteredMaterials.length} 个材料',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '共 ${_allMaterials.length} 个材料',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            // 材料列表 - 减少padding
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMaterials.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.inventory_2 : Icons.search_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12), // 从16减少到12
                              Text(
                                _searchQuery.isEmpty ? '暂无材料' : '未找到匹配的材料',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 6), // 从8减少到6
                                Text(
                                  '尝试使用其他关键词搜索',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12), // 从16减少到12
                          itemCount: _filteredMaterials.length,
                          itemBuilder: (context, index) {
                            final DentalMaterial material = _filteredMaterials[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6), // 从8减少到6
                              child: Padding(
                                padding: const EdgeInsets.all(10), // 从12减少到10
                                child: Row(
                                  children: [
                                    // 材料图标
                                    Container(
                                      width: 36, // 从40减少到36
                                      height: 36, // 从40减少到36
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.inventory, color: Colors.blue[700], size: 18), // 从20减少到18
                                    ),
                                    const SizedBox(width: 10), // 从12减少到10
                                    
                                    // 材料信息
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            material.materialName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3), // 从4减少到3
                                          if (material.materialCode != null) ...[
                                            Text(
                                              '编码: ${material.materialCode}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 1), // 从2减少到1
                                          ],
                                          Row(
                                            children: [
                                              Text(
                                                '单位: ${material.unit}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 12), // 从16减少到12
                                              Text(
                                                '价格: ¥${material.defaultPrice.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (material.supplier != null && material.supplier!.isNotEmpty) ...[
                                            const SizedBox(height: 1), // 从2减少到1
                                            Text(
                                              '供应商: ${material.supplier}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    
                                    // 选择按钮
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(material),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), // 减少padding
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      child: const Text('选择'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
