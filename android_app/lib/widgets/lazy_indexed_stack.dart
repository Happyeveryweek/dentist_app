import 'package:flutter/material.dart';

/// 首次选中时才创建页面，创建后持续保留其状态。
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final Set<int> _visitedIndexes = {widget.index};

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visitedIndexes.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(
        widget.children.length,
        (index) =>
            _visitedIndexes.contains(index)
                ? TickerMode(
                  enabled: index == widget.index,
                  child: widget.children[index],
                )
                : const SizedBox.shrink(),
      ),
    );
  }
}
