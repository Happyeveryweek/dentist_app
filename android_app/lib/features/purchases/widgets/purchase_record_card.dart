import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/widgets/app_card.dart';
import '../../../models/purchase_record.dart';

/// 采购记录卡片组件
/// 职责：显示单个采购记录的详细信息
class PurchaseRecordCard extends StatelessWidget {
  final PurchaseRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PurchaseRecordCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 6),
                _buildQuantityInfo(),
                if (record.supplier?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  _buildSupplierInfo(),
                ],
                if (record.doctor?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  _buildDoctorInfo(),
                ],
                if (record.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  _buildNotesInfo(),
                ],
                const SizedBox(height: 8),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建卡片头部（记录ID、日期、金额）
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '采购记录 #${record.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '采购日期: ${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '¥${NumberFormat('#,##0.00').format(record.totalAmount)}',
            style: TextStyle(
              color: Colors.green[800],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建数量信息
  Widget _buildQuantityInfo() {
    return Row(
      children: [
        Icon(Icons.inventory, size: 14, color: Colors.blue[600]),
        const SizedBox(width: 3),
        Text(
          '总数量: ${record.totalQuantity}',
          style: TextStyle(
            color: Colors.blue[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.list, size: 14, color: Colors.orange[600]),
        const SizedBox(width: 3),
        Text(
          '项目数: ${record.totalQuantity > 0 ? record.totalQuantity : '待定'}',
          style: TextStyle(
            color: Colors.orange[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建供应商信息
  Widget _buildSupplierInfo() {
    return Row(
      children: [
        Icon(Icons.business, size: 14, color: Colors.purple[600]),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            '供应商: ${record.supplier}',
            style: TextStyle(
              color: Colors.purple[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建医生信息
  Widget _buildDoctorInfo() {
    return Row(
      children: [
        Icon(Icons.person, size: 14, color: Colors.teal[600]),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            '采购医生: ${record.doctor}',
            style: TextStyle(
              color: Colors.teal[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建备注信息
  Widget _buildNotesInfo() {
    return Row(
      children: [
        Icon(Icons.note, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            '备注: ${record.notes}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 构建卡片底部（创建时间、操作按钮）
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '创建时间: ${DateFormat('yyyy-MM-dd').format(record.createdAt)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: Material(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.visibility,
                      color: Colors.blue[700],
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.delete, color: Colors.red[700], size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
