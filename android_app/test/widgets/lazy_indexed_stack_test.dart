import 'package:dentist_app/widgets/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('页面首次选中时创建，切换后保持原状态', (tester) async {
    final created = <int>[];

    Widget buildStack(int index) {
      return MaterialApp(
        home: LazyIndexedStack(
          index: index,
          children: [
            _StateProbe(id: 0, onCreated: created.add),
            _StateProbe(id: 1, onCreated: created.add),
          ],
        ),
      );
    }

    await tester.pumpWidget(buildStack(0));
    expect(created, [0]);

    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(buildStack(1));
    expect(created, [0, 1]);

    await tester.pumpWidget(buildStack(0));
    expect(created, [0, 1]);
    expect(find.text('1'), findsOneWidget);
  });
}

class _StateProbe extends StatefulWidget {
  final int id;
  final ValueChanged<int> onCreated;

  const _StateProbe({required this.id, required this.onCreated});

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  int value = 0;

  @override
  void initState() {
    super.initState();
    widget.onCreated(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => value++),
      child: Text('$value'),
    );
  }
}
