import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../providers/purchase_provider.dart';
import 'package:dentist_app/features/purchases/widgets/purchase_item_dialog.dart';
import 'package:dentist_app/features/purchases/widgets/purchase_record_dialog.dart';
import '../widgets/toast_manager.dart';
import '../widgets/confirm_dialogs.dart';
import '../utils/permission_utils.dart';
import '../utils/datetime_formatter.dart';
import '../features/purchases/widgets/purchase_basic_info_card.dart';
import '../features/purchases/widgets/purchase_items_card.dart';
import '../features/purchases/widgets/purchase_amount_card.dart';
import '../features/purchases/widgets/purchase_export_options_dialog.dart';
import '../features/purchases/services/purchase_export_service.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final PurchaseRecord record;

  const PurchaseDetailScreen({super.key, required this.record});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  List<PurchaseItem> _purchaseItems = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPurchaseItems();
  }

  Future<void> _loadPurchaseItems() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // ✅ 检查数据库连接状态
      if (!purchaseProvider.isInitialized) {
        throw Exception('数据库未初始化，请检查数据库连接');
      }
      
      print('🔄 开始加载采购项目，记录ID: ${widget.record.id}');
      final items = await purchaseProvider.getPurchaseItemsByRecordId(widget.record.id!);
      
      // ✅ 按更新时间降序排序，确保最新添加/更新的项目显示在最上面
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      print('✅ 成功加载 ${items.length} 个采购项目，按更新时间排序');
      setState(() {
        _purchaseItems = items;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 加载采购项目失败: $e');
      setState(() {
        _hasError = true;
        _errorMessage = '加载采购项目失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('采购记录详情 #${widget.record.id}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _showExportOptions(context),
            tooltip: '导出为图片',
          ),
          PermissionWrapper(
            module: 'purchase',
            action: 'edit',
            recordDoctor: widget.record.doctor,
            onPermissionDenied: () {
              PermissionUtils.showPermissionDeniedMessage(
                context,
                customMessage: '您只能编辑自己的采购记录',
              );
            },
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editPurchaseRecord(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deletePurchaseRecord(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基本信息
            _buildBasicInfoCard(),
            const SizedBox(height: 16),
            
            // 采购项目明细
            _buildItemsCard(),
            const SizedBox(height: 16),
            
            // 金额信息
            _buildAmountCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return PurchaseBasicInfoCard(record: widget.record);
  }

  Widget _buildItemsCard() {
    return PurchaseItemsCard(
      purchaseItems: _purchaseItems,
      isLoading: _isLoading,
      hasError: _hasError,
      errorMessage: _errorMessage,
      onRetry: _loadPurchaseItems,
      onAddItem: () => _addPurchaseItem(context),
    );
  }


  Widget _buildAmountCard() {
    return PurchaseAmountCard(
      record: widget.record,
      itemCount: _purchaseItems.length,
    );
  }



  void _addPurchaseItem(BuildContext context) async {
    final result = await showDialog<PurchaseItem>(
      context: context,
      builder: (context) => PurchaseItemDialog(
        purchaseRecordId: widget.record.id!, // ✅ 传递采购记录ID
      ),
    );
    
    if (result != null) {
      // 添加采购项目到数据库
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        
        // ✅ 确保项目有正确的采购记录ID和统一的时间格式
        final now = DateTimeFormatter.nowLocal();
        final purchaseItem = result.copyWith(
          purchaseRecordId: widget.record.id!,
          createdAt: now,
          updatedAt: now,
        );
        
        final itemId = await purchaseProvider.addPurchaseItem(purchaseItem);
        if (itemId > 0) {
          // 重新加载采购项目
          await _loadPurchaseItems();
          
          // ✅ 显示成功提示
          if (mounted) {
            // 使用公共组件的绿色背景成功提示
            SuccessToastManager.show(
              context,
              message: '采购项目添加成功',
              duration: const Duration(seconds: 2),
            );
          }
        } else {
          throw Exception('添加失败：返回ID无效');
        }
      } catch (e) {
        print('添加采购项目失败: $e');
        if (mounted) {
          // 使用公共组件的错误提示
          SuccessToastManager.showError(
            context,
            message: '添加失败: $e',
            duration: const Duration(seconds: 3),
          );
        }
      }
    }
  }

  void _editPurchaseRecord(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PurchaseRecordDialog(record: widget.record),
    );
    
    if (result == true) {
      // 编辑成功，重新加载数据
      await _loadPurchaseItems();
      // 使用公共组件的绿色背景成功提示
      SuccessToastManager.show(
        context,
        message: '采购记录已更新',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _deletePurchaseRecord(BuildContext context) async {
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showPurchaseDelete(
      context,
      purchaseInfo: '采购记录 #${widget.record.id}',
    );

    if (confirmed == true) {
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final success = await purchaseProvider.deletePurchaseRecord(widget.record.id!);
        
        if (success > 0) {
          if (mounted) {
            // 删除成功后返回上一页，并传递删除成功的标志
            Navigator.of(context).pop(true);
            DeleteSuccessToastManager.show(
              context,
              message: '采购记录已删除',
            );
          }
        } else {
          SuccessToastManager.showError(
            context,
            message: '删除失败',
          );
        }
      } catch (e) {
        SuccessToastManager.showError(
          context,
          message: '删除失败: $e',
        );
      }
    }
  }

  // 显示导出选项对话框
  Future<void> _showExportOptions(BuildContext context) async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) => const PurchaseExportOptionsDialog(),
    );
    
    // 如果用户选择了导出选项，则执行导出
    if (result != null) {
      _exportPurchaseRecordAsImage(result);
    }
  }

  /// 导出采购记录为图片
  Future<void> _exportPurchaseRecordAsImage(Map<String, bool> exportOptions) async {
    try {
      // 显示加载提示
      SuccessToastManager.showInfo(
        context,
        message: '正在生成图片...',
      );

      // 使用导出服务生成图片数据
      final exportService = PurchaseExportService();
      final imageData = await exportService.generatePurchaseRecordImage(
        widget.record,
        _purchaseItems,
        exportOptions,
      );
      
      // 保存图片
      final result = await exportService.saveImageToDownloads(imageData);
      
      if (result != null) {
        // 显示成功提示
        SuccessToastManager.show(
          context,
          message: '图片已保存到: $result',
        );
      } else {
        // 显示失败提示
        SuccessToastManager.showError(
          context,
          message: '图片保存失败',
        );
      }
    } catch (e) {
      SuccessToastManager.showError(
        context,
        message: '导出失败: $e',
      );
    }
  }
}
