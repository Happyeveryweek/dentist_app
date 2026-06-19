import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/financial_item.dart';
import '../../../models/financial_record.dart';
import '../../../models/patient.dart';
import '../../../features/financial/helpers/financial_payment_method_helper.dart';

class PatientFinancialPermissionDeniedState extends StatelessWidget {
  const PatientFinancialPermissionDeniedState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.orange.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '权限不足',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              '您只能查看自己医生的患者的财务记录',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFinancialRecordsEmptyState extends StatelessWidget {
  final VoidCallback onAddFinancialRecord;

  const PatientFinancialRecordsEmptyState({
    Key? key,
    required this.onAddFinancialRecord,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '暂无收费记录',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              '点击下方按钮添加第一条收费记录',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddFinancialRecord,
            icon: const Icon(Icons.add),
            label: const Text('添加收费记录'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFinancialRecordsList extends StatelessWidget {
  final List<FinancialRecord> records;
  final List<FinancialItem> financialItems;
  final Patient patient;
  final double patientTotalReceivable;
  final bool canViewRecords;
  final void Function(FinancialRecord record) onViewRecord;
  final void Function(FinancialRecord record) onEditRecord;
  final void Function(FinancialRecord record) onDeleteRecord;
  final VoidCallback onPermissionDenied;

  const PatientFinancialRecordsList({
    Key? key,
    required this.records,
    required this.financialItems,
    required this.patient,
    required this.patientTotalReceivable,
    required this.canViewRecords,
    required this.onViewRecord,
    required this.onEditRecord,
    required this.onDeleteRecord,
    required this.onPermissionDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final items = financialItems
            .where((item) => item.financialRecordId == record.id)
            .toList();

        return PatientFinancialRecordCard(
          record: record,
          items: items,
          patient: patient,
          patientTotalReceivable: patientTotalReceivable,
          canViewRecords: canViewRecords,
          onView: () => onViewRecord(record),
          onEdit: () => onEditRecord(record),
          onDelete: () => onDeleteRecord(record),
          onPermissionDenied: onPermissionDenied,
        );
      },
    );
  }
}

class PatientFinancialRecordCard extends StatelessWidget {
  final FinancialRecord record;
  final List<FinancialItem> items;
  final Patient patient;
  final double patientTotalReceivable;
  final bool canViewRecords;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPermissionDenied;

  const PatientFinancialRecordCard({
    Key? key,
    required this.record,
    required this.items,
    required this.patient,
    required this.patientTotalReceivable,
    required this.canViewRecords,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onPermissionDenied,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalReceivable = items.fold<double>(
      0,
      (sum, item) => sum + item.itemPrice,
    );

    final totalCollected = items.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );

    final outstandingAmount = totalReceivable - totalCollected;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinancialRecordHeader(
                patient: patient,
                record: record,
              ),
              const SizedBox(height: 12),
              _FinancialItemsPreview(items: items),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CompactFinancialInfoItem(
                      icon: Icons.calculate,
                      label: '应收费',
                      value: '¥${patientTotalReceivable.toStringAsFixed(2)}',
                      valueColor: Colors.purple[700],
                    ),
                  ),
                  Expanded(
                    child: _CompactFinancialInfoItem(
                      icon: Icons.payment,
                      label: '当前应收费',
                      value: '¥${totalReceivable.toStringAsFixed(2)}',
                      valueColor: Colors.blue[700],
                    ),
                  ),
                  Expanded(
                    child: _CompactFinancialInfoItem(
                      icon: Icons.check_circle,
                      label: '已收费',
                      value: '¥${totalCollected.toStringAsFixed(2)}',
                      valueColor: Colors.green[700],
                    ),
                  ),
                  Expanded(
                    child: _CompactFinancialInfoItem(
                      icon: Icons.warning,
                      label: '欠费',
                      value: '¥${outstandingAmount.toStringAsFixed(2)}',
                      valueColor:
                          outstandingAmount > 0 ? Colors.red : Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FinancialRecordActions(
                canViewRecords: canViewRecords,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
                onPermissionDenied: onPermissionDenied,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinancialRecordHeader extends StatelessWidget {
  final Patient patient;
  final FinancialRecord record;

  const _FinancialRecordHeader({
    required this.patient,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final isFemale =
        patient.gender == '女' || patient.gender.toLowerCase() == 'female';

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: (isFemale ? Colors.pink : Colors.blue).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              patient.name.isNotEmpty ? patient.name[0] : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isFemale ? Colors.pink : Colors.blue,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinancialItemsPreview extends StatelessWidget {
  final List<FinancialItem> items;

  const _FinancialItemsPreview({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: constraints.maxWidth * 0.33,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.list, size: 16, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '收费记录',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const _FinancialItemPreviewHeader(),
                  const SizedBox(height: 6),
                  ...items.take(5).map((item) => _FinancialItemPreviewRow(item: item)),
                  if (items.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, top: 2.0),
                      child: Text(
                        '+${items.length - 5} 更多记录',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                      child: Text(
                        '暂无收费记录',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinancialItemPreviewRow extends StatelessWidget {
  final FinancialItem item;

  const _FinancialItemPreviewRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                item.itemName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '¥${item.itemPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '¥${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              DateFormat('MM-dd').format(item.chargeDate),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 30,
            child: Center(
              child: _buildPaymentMethodIcon(item.paymentMethod),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodIcon(String? paymentMethod) {
    final iconPath = FinancialPaymentMethodHelper.iconAssetPathOrNull(paymentMethod);
    if (iconPath == null) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: FinancialPaymentMethodHelper.displayNameOrDefault(paymentMethod),
      child: SizedBox(
        width: 14,
        height: 14,
        child: Image.asset(
          iconPath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _FinancialItemPreviewHeader extends StatelessWidget {
  const _FinancialItemPreviewHeader();

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 11,
      color: Colors.grey.shade600,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text('收费项目', style: headerStyle),
            ),
          ),
          Expanded(flex: 1, child: Text('应收费', style: headerStyle)),
          Expanded(flex: 1, child: Text('已收费', style: headerStyle)),
          Expanded(flex: 1, child: Text('日期', style: headerStyle)),
          SizedBox(
            width: 30,
            child: Text('方式', style: headerStyle, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _CompactFinancialInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _CompactFinancialInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinancialRecordActions extends StatelessWidget {
  final bool canViewRecords;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPermissionDenied;

  const _FinancialRecordActions({
    required this.canViewRecords,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onPermissionDenied,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (canViewRecords) ...[
          TextButton.icon(
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('查看'),
            onPressed: onView,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('编辑'),
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('删除'),
            onPressed: onDelete,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ] else ...[
          TextButton.icon(
            icon: const Icon(Icons.lock, size: 18),
            label: const Text('权限不足'),
            onPressed: onPermissionDenied,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}
