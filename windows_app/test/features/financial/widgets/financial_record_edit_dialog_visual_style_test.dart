import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('编辑收费项弹窗的区块颜色收敛为主题色和中性色', () {
    final source = File(
      'lib/features/financial/widgets/financial_record_edit_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('color: tokens.cardBackground'));
    expect(source, contains('border: Border.all(color: tokens.border)'));
    expect(source, contains('OutlinedButton.icon('));
    expect(source, contains('fontWeight: FontWeight.bold'));
    expect(source, contains('DentalAvatar('));
    expect(source, isNot(contains('MedicalSemanticColors.')));
    expect(
        source,
        isNot(contains('color: tokens.warningContainer,\n'
            '        borderRadius: BorderRadius.circular(16)')));
    expect(
        source,
        isNot(contains('color: tokens.successContainer,\n'
            '        borderRadius: BorderRadius.circular(16)')));
  });

  test('编辑财务记录表单移除大面积语义色区块', () {
    final source = File(
      'lib/features/financial/widgets/financial_form_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('color: tokens.cardBackground'));
    expect(source, contains('border: Border.all(color: tokens.border)'));
    expect(source, isNot(contains('color: tokens.infoContainer')));
    expect(source, isNot(contains('color: tokens.warningContainer')));
    expect(source, isNot(contains('color: tokens.successContainer')));
  });

  test('财务详情的患者信息和统计区使用中性底板与浅色头像', () {
    final patientSource = File(
      'lib/features/financial/widgets/financial_patient_info_section.dart',
    ).readAsStringSync();
    final statsSource = File(
      'lib/features/financial/widgets/financial_detail_stats_section.dart',
    ).readAsStringSync();
    final statItemSource = File(
      'lib/features/financial/widgets/financial_stat_item.dart',
    ).readAsStringSync();

    expect(patientSource, contains('DentalAvatar('));
    expect(patientSource, contains('color: context.tokens.cardBackground'));
    expect(statsSource, contains('color: context.tokens.cardBackground'));
    expect(statsSource, contains('Border.all(color: context.tokens.border)'));
    expect(
      statsSource,
      contains('EdgeInsets.symmetric(horizontal: 14, vertical: 3)'),
    );
    expect(statItemSource, contains('Icon(icon, color: color, size: 20)'));
  });

  test('财务详情列表占满中间区域且编辑弹窗使用固定高度列表', () {
    final detailSource =
        File('lib/screens/financial_detail_screen.dart').readAsStringSync();
    final editSource = File(
      'lib/features/financial/widgets/financial_record_edit_dialog.dart',
    ).readAsStringSync();
    final rowSource = File(
      'lib/features/financial/widgets/financial_detail_record_card.dart',
    ).readAsStringSync();

    expect(
      detailSource,
      contains('// 收费记录面板占满中间剩余区域，超出后在面板内滚动'),
    );
    expect(detailSource, contains('onPressed: _editCurrentFinancialRecord'));
    expect(detailSource, contains("label: const Text('取消')"));
    expect(detailSource, contains('availableHeight > 720 ? 720'));
    expect(detailSource, contains('controller: _scrollController'));
    expect(editSource, contains('height: 300'));
    expect(editSource, contains('controller: _itemsScrollController'));
    expect(editSource, contains('maxLines: 1'));
    expect(rowSource, contains('border: Border('));
    expect(rowSource, isNot(contains('boxShadow:')));
  });
}
