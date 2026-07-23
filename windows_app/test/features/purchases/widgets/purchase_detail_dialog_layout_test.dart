import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('采购详情使用固定高度明细面板和底部操作按钮', () {
    final source = File(
      'lib/features/purchases/widgets/purchase_detail_dialog.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('height: MediaQuery.of(context).size.height * 0.72'),
    );
    expect(source, contains('child: Scrollbar('));
    expect(source, contains('controller: _itemsScrollController'));
    expect(
      source,
      contains('ListView.builder(\n'
          '                                controller: _itemsScrollController'),
    );
    expect(source, contains("label: const Text('编辑')"));
    expect(source, contains("label: const Text('取消')"));
    expect(source, isNot(contains('height: 720')));
    expect(source, isNot(contains("label: const Text('编辑记录')")));
  });

  test('采购编辑项目区有独立外框且操作统一为取消和保存', () {
    final itemSource = File(
      'lib/features/purchases/widgets/purchase_form_item_list_section.dart',
    ).readAsStringSync();
    final actionSource = File(
      'lib/features/purchases/widgets/purchase_form_actions_section.dart',
    ).readAsStringSync();
    final dialogSource = File(
      'lib/features/purchases/widgets/purchase_form_dialog.dart',
    ).readAsStringSync();

    expect(itemSource, contains('clipBehavior: Clip.antiAlias'));
    expect(itemSource, contains('height: 48'));
    expect(itemSource, contains('bottom: BorderSide('));
    expect(
      itemSource,
      isNot(contains('index.isOdd\n'
          '                              ? context.tokens.mutedBackground')),
    );
    expect(itemSource,
        isNot(contains('margin: const EdgeInsets.only(bottom: 8)')));
    expect(dialogSource, contains('height: screenSize.height * 0.9'));
    expect(actionSource, contains("label: const Text('取消')"));
    expect(actionSource, contains("Text(isLoading ? '保存中...' : '保存')"));
    expect(actionSource, isNot(contains("'更新记录'")));
  });
}
