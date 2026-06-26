import 'package:flutter/material.dart';

class FinancialDetailTableColumn {
  const FinancialDetailTableColumn({
    required this.label,
    this.flex,
    this.width,
    this.headerTextAlign = TextAlign.center,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 4),
  }) : assert((flex == null) != (width == null));

  final String label;
  final int? flex;
  final double? width;
  final TextAlign headerTextAlign;
  final EdgeInsetsGeometry cellPadding;
}

class FinancialDetailTableLayout {
  static const double rowHeight = 48;

  static const List<FinancialDetailTableColumn> columns = [
    FinancialDetailTableColumn(label: '收费日期', flex: 14),
    FinancialDetailTableColumn(label: '收费项目', flex: 23),
    FinancialDetailTableColumn(label: '收费方式', flex: 15),
    FinancialDetailTableColumn(label: '应收费', flex: 12),
    FinancialDetailTableColumn(label: '已收费', flex: 12),
    FinancialDetailTableColumn(label: '加工费', flex: 12),
    FinancialDetailTableColumn(
      label: '操作',
      width: 85,
      cellPadding: EdgeInsets.zero,
    ),
  ];

  static Widget buildHeader({
    BorderRadius? borderRadius,
    BoxBorder? border,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(0, 8, 0, 8),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
        border: border,
      ),
      child: buildRow(
        children: columns
            .map(
              (column) => Text(
                column.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: column.headerTextAlign,
              ),
            )
            .toList(),
      ),
    );
  }

  static Widget buildRow({required List<Widget> children}) {
    assert(children.length == columns.length);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(
        columns.length,
        (index) => _wrap(columns[index], children[index]),
      ),
    );
  }

  static Widget _wrap(FinancialDetailTableColumn column, Widget child) {
    final paddedChild = Padding(
      padding: column.cellPadding,
      child: child,
    );

    if (column.width != null) {
      return SizedBox(width: column.width, child: paddedChild);
    }

    final flex = column.flex;
    return Expanded(
      flex: flex ?? 1,
      child: paddedChild,
    );
  }
}
