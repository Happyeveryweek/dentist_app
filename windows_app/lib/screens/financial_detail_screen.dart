import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/patient.dart';
import '../providers/financial_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/success_toast.dart';
import '../widgets/modern_date_picker.dart';
import '../utils/permission_utils.dart';
import '../features/financial/helpers/financial_payment_method_helper.dart';
import '../features/financial/widgets/financial_patient_info_section.dart';
import '../features/financial/widgets/financial_detail_stats_section.dart';
import '../features/financial/widgets/financial_detail_table_header.dart';
import '../features/financial/widgets/financial_records_list_header.dart';
import '../features/financial/widgets/financial_detail_record_card.dart';
import '../features/financial/widgets/financial_detail_editing_item_row.dart';
import '../features/financial/services/financial_detail_service.dart';
import 'patient_detail_screen.dart';
import '../utils/log_manager.dart';

class FinancialDetailScreen extends StatefulWidget {
  final Patient patient;
  final int? initialRecordId;

  const FinancialDetailScreen({
    Key? key,
    required this.patient,
    this.initialRecordId,
  }) : super(key: key);

  @override
  State<FinancialDetailScreen> createState() => _FinancialDetailScreenState();
}

class _FinancialDetailScreenState extends State<FinancialDetailScreen> {
  List<FinancialRecord> _patientRecords = [];
  List<Map<String, dynamic>> _detailedRecords = []; // 存储详细记录（包含明细项）
  bool _isLoading = true;
  final bool _isEditing = false; // 新增：编辑状态标志
  bool _showProcessingFee = false;
  String _errorMessage = '';
  final ScrollController _scrollController = ScrollController();
  bool _hasDataChanged = false; // 跟踪数据是否有变动

  // 成功消息显示
  String? _successMessage;
  bool _showSuccessMessage = false;
  bool _isDeleteMessage = false; // 是否是删除消息

  // 内联编辑状态
  int? _editingItemId; // null表示无编辑，-1表示新增行
  final TextEditingController _editChargeDateController =
      TextEditingController();
  final TextEditingController _editItemNameController = TextEditingController();
  String? _editPaymentMethod =
      FinancialPaymentMethodHelper.defaultPaymentMethod;
  final TextEditingController _editItemPriceController =
      TextEditingController();
  final TextEditingController _editProcessingFeeController =
      TextEditingController();
  final TextEditingController _editTotalPriceController =
      TextEditingController();
  DateTime _editChargeDate = DateTime.now();
  FinancialRecord? _editingRecord; // 当前正在编辑的财务记录

  // 业务逻辑 Service
  late FinancialDetailService _financialDetailService;

  @override
  void dispose() {
    _scrollController.dispose();
    _editChargeDateController.dispose();
    _editItemNameController.dispose();
    _editItemPriceController.dispose();
    _editProcessingFeeController.dispose();
    _editTotalPriceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 初始化业务逻辑 Service
    final financialProvider =
        Provider.of<FinancialProvider>(context, listen: false);
    _financialDetailService =
        FinancialDetailService(financialProvider: financialProvider);

    // 检查权限，如果没有权限则不加载数据
    if (_canViewPatientFinancialRecords()) {
      _loadPatientRecords();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '权限不足：您只能查看自己医生的患者的财务记录';
      });
    }
  }

  // 加载患者的财务记录
  void _scrollToHighlightedRecord() {
    if (_detailedRecords.isEmpty) return;

    // 查找高亮记录的索引
    final highlightedIndex = _detailedRecords
        .indexWhere((detailRecord) => detailRecord['isHighlighted'] as bool);

    if (highlightedIndex != -1 && _scrollController.hasClients) {
      // 计算滚动位置（居中显示）
      const itemHeight = 120.0; // 估计的卡片高度
      final screenHeight = MediaQuery.of(context).size.height;
      final scrollPosition =
          highlightedIndex * itemHeight - screenHeight / 2 + itemHeight / 2;

      _scrollController.animateTo(
        scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadPatientRecords() async {
    if (!mounted) return;

    final patientId = widget.patient.id;
    if (patientId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '患者 ID 为空，无法加载财务记录';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final detailedRecords = await _financialDetailService.loadPatientRecords(
        patientId,
        widget.initialRecordId,
      );

      // 从详细记录中提取财务记录列表
      final patientRecords = detailedRecords
          .map((detail) => detail['record'] as FinancialRecord)
          .toSet()
          .toList();
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (mounted) {
        setState(() {
          _patientRecords = patientRecords;
          _detailedRecords = detailedRecords;
          _isLoading = false;
        });

        // 如果有初始记录ID，滚动到该记录
        if (widget.initialRecordId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToHighlightedRecord();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取财务记录失败: $e';
        });
      }
    }
  }

  Future<void> _openPatientDetail() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: widget.patient),
      ),
    );

    if (result == true) {
      _hasDataChanged = true;
      await _loadPatientRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    // 检查是否在弹窗中显示
    final isInDialog = ModalRoute.of(context)?.settings.name == null;

    if (isInDialog) {
      // 弹窗模式：不显示AppBar，直接显示内容
      return Scaffold(
        backgroundColor: tokens.cardBackground,
        body: Column(
          children: [
            // 自定义标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: tokens.primaryHeaderGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_hasDataChanged),
                    icon: Icon(Icons.arrow_back, color: tokens.cardBackground),
                    tooltip: '返回',
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.cardBackground.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: tokens.cardBackground,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.patient.name} - 财务详情',
                      style: TextStyle(
                        color: tokens.cardBackground,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openPatientDetail,
                    icon: Icon(Icons.person_search, color: tokens.cardBackground),
                    tooltip: '查看患者详情',
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_hasDataChanged),
                    icon: Icon(Icons.close, color: tokens.cardBackground),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            // 内容区域
            Expanded(child: _buildBody()),
          ],
        ),
      );
    } else {
      // 页面模式：显示完整的AppBar
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasDataChanged),
            tooltip: '返回',
          ),
          title: Text('${widget.patient.name} - 财务详情'),
          backgroundColor: tokens.cardBackground,
          foregroundColor: colors.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _openPatientDetail,
              icon: const Icon(Icons.person_search),
              tooltip: '查看患者详情',
            ),
          ],
        ),
        body: _buildBody(),
      );
    }
  }

  Widget _buildBody() {
    final tokens = context.tokens;
    final colors = context.colors;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: tokens.error),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_errorMessage, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPatientRecords,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_patientRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: tokens.iconMuted),
            const SizedBox(height: 16),
            Text(
              '暂无收费记录',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一条收费记录',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addFinancialRecord,
              icon: const Icon(Icons.add),
              label: const Text('添加记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primaryAccent,
                foregroundColor: tokens.cardBackground,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 患者基本信息
        Padding(
          padding: const EdgeInsets.all(16),
          child: FinancialPatientInfoSection(
            patient: widget.patient,
            notes: _getPatientNotes(),
          ),
        ),

        // 财务统计信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FinancialDetailStatsSection(
            totalReceivable: _totalReceivable,
            totalPaid: _totalPaid,
            totalOutstanding: _totalOutstanding,
          ),
        ),

        // 财务记录列表标题和表头
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16), // 添加顶部间距
              FinancialRecordsListHeader(
                recordCount: _detailedRecords.length,
                showProcessingFee: _showProcessingFee,
                onToggleProcessingFee: () {
                  setState(() {
                    _showProcessingFee = !_showProcessingFee;
                  });
                },
                onAddRecord: _addFinancialRecord,
              ),
              const SizedBox(height: 8),
              const FinancialDetailTableHeader(),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 财务记录列表 - 使用Expanded而不是SingleChildScrollView
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildRecordsList(),
          ),
        ),

        // 成功消息显示区域（在底部）
        if (_showSuccessMessage)
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
            child: InlineSuccessMessage(
              message: _successMessage ?? '',
              isDelete: _isDeleteMessage,
              onDismiss: () {
                setState(() {
                  _showSuccessMessage = false;
                });
              },
            ),
          ),
      ],
    );
  }

  // 获取患者备注信息
  String _getPatientNotes() {
    // 获取患者最新的财务记录备注信息
    if (_patientRecords.isNotEmpty) {
      final latestRecord = _patientRecords.first;
      final notes = latestRecord.notes;
      if (notes != null && notes.isNotEmpty) {
        return notes;
      }
    }
    return '暂无备注信息';
  }

  // 获取或创建财务记录
  Future<FinancialRecord?> _getOrCreateFinancialRecord() async {
    final patientId = widget.patient.id;
    if (patientId == null) {
      LogManager.w('FinancialDetailScreen', '患者 ID 为空，无法获取或创建财务记录');
      return null;
    }
    try {
      return await _financialDetailService
          .getOrCreateFinancialRecord(patientId);
    } catch (e) {
      LogManager.e('FinancialDetailScreen', '获取或创建财务记录失败', error: e);
      return null;
    }
  }

  // 添加财务记录
  Future<void> _addFinancialRecord() async {
    // 检查权限
    if (!_canViewPatientFinancialRecords()) {
      PermissionUtils.showPermissionDeniedDialog(
        context,
        message: '您只能为自己医生的患者添加财务记录。',
      );
      return;
    }

    // 获取或创建财务记录
    FinancialRecord? targetRecord = await _getOrCreateFinancialRecord();

    if (targetRecord == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法创建财务记录')),
      );
      return;
    }

    // 启动内联编辑模式
    setState(() {
      _editingItemId = -1; // -1表示新增行
      _editingRecord = targetRecord;
      _editChargeDate = DateTime.now();
      _editChargeDateController.text =
          DateFormat('yyyy-MM-dd').format(_editChargeDate);
      _editItemNameController.text = '综合收费';
      _editPaymentMethod = FinancialPaymentMethodHelper.defaultPaymentMethod;
      _editItemPriceController.text = '0';
      _editProcessingFeeController.text = '0';
      _editTotalPriceController.text = '0';
    });
  }

  // 编辑财务记录
  Future<void> _editFinancialRecord(FinancialRecord record,
      {FinancialItem? item, bool isDetail = false}) async {
    if (isDetail && item != null) {
      // 启动内联编辑模式
      setState(() {
        _editingItemId = item.id;
        _editingRecord = record;
        _editChargeDate = item.chargeDate;
        _editChargeDateController.text =
            DateFormat('yyyy-MM-dd').format(item.chargeDate);
        _editItemNameController.text = item.itemName;
        _editPaymentMethod = item.paymentMethod;
        _editItemPriceController.text = item.itemPrice % 1 == 0
            ? item.itemPrice.toInt().toString()
            : item.itemPrice.toString();
        _editProcessingFeeController.text = item.processingFee % 1 == 0
            ? item.processingFee.toInt().toString()
            : item.processingFee.toString();
        _editTotalPriceController.text = item.totalPrice % 1 == 0
            ? item.totalPrice.toInt().toString()
            : item.totalPrice.toString();
      });
    }
  }

  // 删除财务记录
  Future<void> _deleteFinancialRecord(FinancialRecord record,
      {FinancialItem? item, bool isDetail = false}) async {
    final patientId = widget.patient.id;
    if (patientId == null) {
      AppToastManager.showError(context, message: '患者 ID 为空，无法删除财务记录');
      return;
    }

    final recordId = record.id;
    if (recordId == null) {
      AppToastManager.showError(context, message: '无法删除无 ID 的财务记录');
      return;
    }

    if (isDetail && item != null) {
      final itemId = item.id;
      if (itemId == null) {
        AppToastManager.showError(context, message: '无法删除无 ID 的收费项目');
        return;
      }

      final recordItems = await _financialDetailService.financialProvider
          .getFinancialItemsByRecordId(recordId);
      final isLastItem = recordItems.length <= 1;

      if (!mounted) return;
      // 删除明细项
      final confirmed = await DeleteConfirmDialogManager.show(
        context,
        title: '确认删除',
        message: '确定要删除患者 "${widget.patient.name}" 的这条收费明细项吗？\n\n'
            '收费项目: ${item.itemName}\n'
            '收费日期: ${DateFormat('yyyy-MM-dd').format(item.chargeDate)}\n'
            '应收费: ¥${item.itemPrice % 1 == 0 ? item.itemPrice.toInt() : item.itemPrice}  '
            '加工费: ¥${item.processingFee % 1 == 0 ? item.processingFee.toInt() : item.processingFee}  '
            '已收费: ¥${item.totalPrice % 1 == 0 ? item.totalPrice.toInt() : item.totalPrice}\n'
            '${isLastItem ? '\n这是该患者这条财务记录的最后一条收费记录，删除后会连带删除整条财务记录。\n' : '\n'}'
            '删除后无法恢复！',
      );

      if (confirmed) {
        try {
          // 删除明细项
          final success =
              await _financialDetailService.deleteFinancialItemAndCleanupRecord(
            itemId: itemId,
            recordId: recordId,
          );

          if (success) {
            // 标记数据已变动
            _hasDataChanged = true;
            if (!isLastItem) {
              // 更新财务记录的收费项数量和更新时间
              await _financialDetailService
                  .updateFinancialRecordAfterItemChange(record);
            }
            // 删除成功后，更新患者的财务统计
            await _financialDetailService
                .updatePatientFinancialSummary(patientId);
            // 重新加载数据
            await _loadPatientRecords();

            // 显示成功提示（橙色提示条）
            _showInlineSuccessMessage(
              isLastItem ? '已删除最后一条收费记录，并同步删除财务记录' : '已删除收费明细项',
              isDelete: true,
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('删除失败'),
                backgroundColor: context.tokens.error,
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: context.tokens.error,
            ),
          );
        }
      }
    }
  }

  // 取消编辑
  void _cancelEditing() {
    setState(() {
      _editingItemId = null;
      _editingRecord = null;
      _editChargeDateController.clear();
      _editItemNameController.clear();
      _editPaymentMethod = FinancialPaymentMethodHelper.defaultPaymentMethod;
      _editItemPriceController.clear();
      _editProcessingFeeController.clear();
      _editTotalPriceController.clear();
    });
  }

  // 保存当前编辑的收费项
  Future<void> _saveEditingItem() async {
    // 验证表单
    if (_editItemNameController.text.trim().isEmpty) {
      AppToastManager.showError(context, message: '请输入收费项目名称');
      return;
    }

    final patientId = widget.patient.id;
    if (patientId == null) {
      AppToastManager.showError(context, message: '患者 ID 为空');
      return;
    }

    final editingRecord = _editingRecord;
    if (editingRecord == null) {
      AppToastManager.showError(context, message: '无法找到财务记录');
      return;
    }

    final editingRecordId = editingRecord.id;
    if (editingRecordId == null) {
      AppToastManager.showError(context, message: '财务记录 ID 为空');
      return;
    }

    try {
      if (_editingItemId == -1) {
        // 新增收费项
        final newItem = FinancialItem(
          financialRecordId: editingRecordId,
          itemName: _editItemNameController.text.trim(),
          paymentMethod: FinancialPaymentMethodHelper.toStorageValue(
            _editPaymentMethod,
          ),
          itemPrice: double.tryParse(
                  _editItemPriceController.text.replaceAll('¥', '').trim()) ??
              0.0,
          processingFee: double.tryParse(_editProcessingFeeController.text
                  .replaceAll('¥', '')
                  .trim()) ??
              0.0,
          quantity: 1,
          totalPrice: double.tryParse(
                  _editTotalPriceController.text.replaceAll('¥', '').trim()) ??
              0.0,
          chargeDate: _editChargeDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _financialDetailService.addFinancialItem(newItem);

        // 标记数据已变动
        _hasDataChanged = true;

        // 更新财务记录的收费项数量和更新时间
        await _financialDetailService
            .updateFinancialRecordAfterItemChange(editingRecord);

        // 更新患者的财务统计
        await _financialDetailService
            .updatePatientFinancialSummary(patientId);

        // 重新加载数据
        await _loadPatientRecords();

        // 取消编辑状态
        _cancelEditing();

        // 显示成功提示
        _showInlineSuccessMessage('收费项添加成功');
      } else {
        // 更新现有收费项 - 先检查是否有变化
        final originalItem = _detailedRecords
            .where((dr) =>
                dr['item'] != null &&
                (dr['item'] as FinancialItem).id == _editingItemId)
            .map((dr) => dr['item'] as FinancialItem)
            .first;

        final newItemName = _editItemNameController.text.trim();
        final newPaymentMethod = FinancialPaymentMethodHelper.toStorageValue(
          _editPaymentMethod,
        );
        final newItemPrice = double.tryParse(
                _editItemPriceController.text.replaceAll('¥', '').trim()) ??
            0.0;
        final newProcessingFee = double.tryParse(
                _editProcessingFeeController.text.replaceAll('¥', '').trim()) ??
            0.0;
        final newTotalPrice = double.tryParse(
                _editTotalPriceController.text.replaceAll('¥', '').trim()) ??
            0.0;

        // 检查是否有任何变化
        final hasChanges = originalItem.itemName != newItemName ||
            originalItem.paymentMethod != newPaymentMethod ||
            originalItem.itemPrice != newItemPrice ||
            originalItem.processingFee != newProcessingFee ||
            originalItem.totalPrice != newTotalPrice ||
            originalItem.chargeDate != _editChargeDate;

        if (!hasChanges) {
          // 没有变化，静默取消编辑
          _cancelEditing();
          return;
        }

        final updatedItem = FinancialItem(
          id: originalItem.id,
          financialRecordId: originalItem.financialRecordId,
          itemName: newItemName,
          paymentMethod: newPaymentMethod,
          itemPrice: newItemPrice,
          processingFee: newProcessingFee,
          quantity: originalItem.quantity,
          totalPrice: newTotalPrice,
          chargeDate: _editChargeDate,
          createdAt: originalItem.createdAt,
          updatedAt: DateTime.now(),
        );

        await _financialDetailService.updateFinancialItem(updatedItem);

        // 标记数据已变动
        _hasDataChanged = true;

        // 更新财务记录的收费项数量和更新时间
        await _financialDetailService
            .updateFinancialRecordAfterItemChange(editingRecord);

        // 更新患者的财务统计
        await _financialDetailService
            .updatePatientFinancialSummary(patientId);

        // 重新加载数据
        await _loadPatientRecords();

        // 取消编辑状态
        _cancelEditing();

        // 显示成功提示
        _showInlineSuccessMessage('收费项更新成功');
      }
    } catch (e) {
      if (!mounted) return;
      AppToastManager.showError(context, message: '保存失败: $e');
    }
  }

  // 计算统计数据
  double get _totalReceivable {
    // 从financial_items表中计算应收费金额（不包含加工费）
    double total = 0.0;
    for (final detailRecord in _detailedRecords) {
      final item = detailRecord['item'] as FinancialItem?;
      if (detailRecord['isDetail'] == true && item != null) {
        total += (item.itemPrice * item.quantity);
      }
    }
    return total;
  }

  double get _totalPaid {
    // 从financial_items表中计算已收费金额
    double total = 0.0;
    for (final detailRecord in _detailedRecords) {
      final item = detailRecord['item'] as FinancialItem?;
      if (detailRecord['isDetail'] == true && item != null) {
        total += item.totalPrice;
      }
    }
    return total;
  }

  double get _totalOutstanding {
    // 从financial_items表中计算欠费金额（应收费 - 已收费）
    return _totalReceivable - _totalPaid;
  }

  // 构建财务记录列表
  Widget _buildRecordsList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _detailedRecords.length +
          (_editingItemId == -1 ? 1 : 0), // 如果是新增模式，增加一行
      itemBuilder: (context, index) {
        // 如果是新增行（放在最上面）
        if (_editingItemId == -1 && index == 0) {
          return FinancialDetailEditingItemRow(
            chargeDateController: _editChargeDateController,
            itemNameController: _editItemNameController,
            paymentMethod: _editPaymentMethod,
            itemPriceController: _editItemPriceController,
            processingFeeController: _editProcessingFeeController,
            totalPriceController: _editTotalPriceController,
            chargeDate: _editChargeDate,
            onDateSelect: () async {
              final date = await showDialog<DateTime>(
                context: context,
                builder: (context) => ModernDatePickerDialog(
                  initialDate: _editChargeDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  title: '选择收费日期',
                ),
              );
              if (date != null) {
                setState(() {
                  _editChargeDate = date;
                  _editChargeDateController.text =
                      DateFormat('yyyy-MM-dd').format(date);
                });
              }
              return date;
            },
            onPaymentMethodChanged: (value) {
              if (value == null) return;
              setState(() {
                _editPaymentMethod = value;
              });
            },
            onSave: _saveEditingItem,
            onCancel: _cancelEditing,
          );
        }

        // 调整索引（如果有新增行）
        final actualIndex = _editingItemId == -1 ? index - 1 : index;
        final detailRecord = _detailedRecords[actualIndex];
        final record = detailRecord['record'] as FinancialRecord;
        final item = detailRecord['item'] as FinancialItem?;
        final isDetail = detailRecord['isDetail'] as bool;
        final isHighlighted = detailRecord['isHighlighted'] as bool;
        final isEditing = item != null && _editingItemId == item.id;

        if (isEditing) {
          return FinancialDetailEditingItemRow(
            chargeDateController: _editChargeDateController,
            itemNameController: _editItemNameController,
            paymentMethod: _editPaymentMethod,
            itemPriceController: _editItemPriceController,
            processingFeeController: _editProcessingFeeController,
            totalPriceController: _editTotalPriceController,
            chargeDate: _editChargeDate,
            onDateSelect: () async {
              final date = await showDialog<DateTime>(
                context: context,
                builder: (context) => ModernDatePickerDialog(
                  initialDate: _editChargeDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  title: '选择收费日期',
                ),
              );
              if (date != null) {
                setState(() {
                  _editChargeDate = date;
                  _editChargeDateController.text =
                      DateFormat('yyyy-MM-dd').format(date);
                });
              }
              return date;
            },
            onPaymentMethodChanged: (value) {
              if (value == null) return;
              setState(() {
                _editPaymentMethod = value;
              });
            },
            onSave: _saveEditingItem,
            onCancel: _cancelEditing,
          );
        }

        return FinancialDetailRecordCard(
          record: record,
          item: item,
          isDetail: isDetail,
          isHighlighted: isHighlighted,
          isEditing: _isEditing,
          showProcessingFee: _showProcessingFee,
          onEdit: () =>
              _editFinancialRecord(record, item: item, isDetail: isDetail),
          onDelete: () =>
              _deleteFinancialRecord(record, item: item, isDetail: isDetail),
        );
      },
    );
  }

  /// 检查当前用户是否可以查看该患者的财务记录
  bool _canViewPatientFinancialRecords() {
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

      // 非管理员用户只能查看自己医生的患者的财务记录
      // 如果患者没有指定医生，或者当前用户的医生与患者的医生匹配，则允许查看
      final patientDoctor = widget.patient.doctor;
      if (patientDoctor == null || patientDoctor.isEmpty) {
        // 如果患者没有指定医生，所有用户都可以查看

        return true;
      }

      // 检查当前用户的医生是否与患者的医生匹配
      return currentUser.doctor != null &&
          currentUser.doctor == patientDoctor;
    } catch (e) {
      LogManager.e('FinancialDetailScreen', '检查财务记录查看权限时出错', error: e);
      return false;
    }
  }

  // 显示内联成功消息（短的绿色提示条）
  void _showInlineSuccessMessage(String message, {bool isDelete = false}) {
    setState(() {
      _successMessage = message;
      _showSuccessMessage = true;
      _isDeleteMessage = isDelete;
    });

    // 2秒后自动隐藏
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSuccessMessage = false;
        });
      }
    });
  }
}
