import 'package:flutter/material.dart';

/// 有状态的文本输入框组件
/// 解决 TextField 在父组件 setState 时失去焦点的问题
class StatefulTextField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final TextAlign textAlign;
  final TextStyle? style;
  final InputDecoration? decoration;
  final int? maxLines;
  final Color? cursorColor;

  const StatefulTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.textAlign = TextAlign.start,
    this.style,
    this.decoration,
    this.maxLines = 1,
    this.cursorColor,
  });

  @override
  State<StatefulTextField> createState() => _StatefulTextFieldState();
}

class _StatefulTextFieldState extends State<StatefulTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    
    // 监听文本变化
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void didUpdateWidget(StatefulTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 只有在初始值改变且输入框没有焦点时才更新
    if (widget.initialValue != oldWidget.initialValue && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textAlign: widget.textAlign,
      style: widget.style,
      decoration: widget.decoration ?? const InputDecoration(),
      maxLines: widget.maxLines,
      cursorColor: widget.cursorColor,
    );
  }
}
