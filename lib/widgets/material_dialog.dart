import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/material.dart';
import '../providers/material_provider.dart';

/// 材料对话框
class MaterialDialog extends StatefulWidget {
  final Material? material; // 如果是编辑模式，传入现有材料

  const MaterialDialog({
    super.key,
    this.material,
  });

  @override
  State<MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<MaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _materialNameController = TextEditingController();
  final _materialCodeController = TextEditingController();
  final _unitController = TextEditingController();
  final _defaultPriceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _isGeneratingCode = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _materialNameController.dispose();
    _materialCodeController.dispose();
    _unitController.dispose();
    _defaultPriceController.dispose();
    _supplierController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 初始化表单
  void _initializeForm() {
    if (widget.material != null) {
      // 编辑模式
      _materialNameController.text = widget.material!.materialName;
      _materialCodeController.text = widget.material!.materialCode ?? '';
      _unitController.text = widget.material!.unit;
      _defaultPriceController.text = widget.material!.defaultPrice.toString();
      _supplierController.text = widget.material!.supplier ?? '';
      _descriptionController.text = widget.material!.description ?? '';
    } else {
      // 新增模式
      _unitController.text = '个'; // 默认单位
      _defaultPriceController.text = '0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(),
            
            // 表单内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 材料名称
                      _buildMaterialNameField(),
                      
                      // 材料编码
                      _buildMaterialCodeField(),
                      
                      // 单位和价格
                      _buildUnitAndPriceFields(),
                      
                      // 供应商
                      _buildSupplierField(),
                      
                      // 描述
                      _buildDescriptionField(),
                    ],
                  ),
                ),
              ),
            ),
            
            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.material != null ? Icons.edit : Icons.add,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            widget.material != null ? '编辑材料' : '新增材料',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建材料名称字段
  Widget _buildMaterialNameField() {
    return TextFormField(
      controller: _materialNameController,
      decoration: const InputDecoration(
        labelText: '材料名称 *',
        hintText: '请输入材料名称',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入材料名称';
        }
        return null;
      },
    );
  }

  /// 构建材料编码字段
  Widget _buildMaterialCodeField() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _materialCodeController,
              decoration: const InputDecoration(
                labelText: '材料编码',
                hintText: '请输入材料编码',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isGeneratingCode ? null : _generateMaterialCode,
            child: _isGeneratingCode
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('生成编码'),
          ),
        ],
      ),
    );
  }

  /// 构建单位和价格字段
  Widget _buildUnitAndPriceFields() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: '单位 *',
                hintText: '个、盒、支等',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入单位';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _defaultPriceController,
              decoration: const InputDecoration(
                labelText: '默认价格 *',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixText: '¥',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入默认价格';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效价格';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建供应商字段
  Widget _buildSupplierField() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: _supplierController,
        decoration: const InputDecoration(
          labelText: '供应商',
          hintText: '请输入供应商名称',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  /// 构建描述字段
  Widget _buildDescriptionField() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(
          labelText: '描述',
          hintText: '请输入材料描述信息',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveMaterial,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.material != null ? '更新' : '保存'),
          ),
        ],
      ),
    );
  }

  /// 生成材料编码
  Future<void> _generateMaterialCode() async {
    setState(() {
      _isGeneratingCode = true;
    });

    try {
      final provider = Provider.of<MaterialProvider>(context, listen: false);
      final code = await provider.generateMaterialCode();
      
      setState(() {
        _materialCodeController.text = code;
        _isGeneratingCode = false;
      });
    } catch (e) {
      setState(() {
        _isGeneratingCode = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成编码失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 保存材料
  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<MaterialProvider>(context, listen: false);
      
      // 检查材料名称是否已存在
      final exists = await provider.isMaterialNameExists(
        _materialNameController.text,
        excludeId: widget.material?.id,
      );
      
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('材料名称已存在，请使用其他名称'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final material = Material(
        id: widget.material?.id,
        materialName: _materialNameController.text,
        materialCode: _materialCodeController.text.isEmpty ? null : _materialCodeController.text,
        unit: _unitController.text,
        defaultPrice: double.parse(_defaultPriceController.text),
        supplier: _supplierController.text.isEmpty ? null : _supplierController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      );

      if (widget.material != null) {
        // 更新模式
        await provider.updateMaterial(material);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('材料更新成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 新增模式
        final id = await provider.addMaterial(material);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('材料创建成功，ID: $id'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // 返回true表示操作成功
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
