import 'package:flutter/material.dart';
import '../../../theme/theme_context_extensions.dart';
import 'financial_detail_table_layout.dart';

/// 财务详情页表头组件
/// 用于显示财务记录列表的表头（日期、收费项目、收费方式、应收费、已收费、加工费、操作）
class FinancialDetailTableHeader extends StatelessWidget {
  const FinancialDetailTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FinancialDetailTableLayout.rowHeight,
      child: FinancialDetailTableLayout.buildHeader(
        context,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.tokens.border),
      ),
    );
  }
}
