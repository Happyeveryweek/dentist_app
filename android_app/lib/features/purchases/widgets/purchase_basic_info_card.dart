import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/purchase_record.dart';
import '../../../widgets/app_card.dart';
import 'purchase_info_row.dart';

/// 采购记录基本信息卡片
class PurchaseBasicInfoCard extends StatelessWidget {
  final PurchaseRecord record;

  const PurchaseBasicInfoCard({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          PurchaseInfoRow('记录ID:', '#${record.id}'),
          PurchaseInfoRow('采购日期:', DateFormat('yyyy-MM-dd').format(record.purchaseDate)),
          PurchaseInfoRow('供应商:', record.supplier ?? '未指定'),
          PurchaseInfoRow('采购医生:', record.doctor ?? '未指定'),
          PurchaseInfoRow('备注:', record.notes ?? '无'),
          PurchaseInfoRow('创建时间:', DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt)),
          if (record.updatedAt != record.createdAt)
            PurchaseInfoRow('更新时间:', DateFormat('yyyy-MM-dd HH:mm').format(record.updatedAt)),
        ],
      ),
    );
  }
}
