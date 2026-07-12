import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class TeethConditionWidget extends StatefulWidget {
  final List<Map<String, String>> teethData;
  final ValueChanged<List<Map<String, String>>> onChanged;

  const TeethConditionWidget({
    Key? key,
    required this.teethData,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<TeethConditionWidget> createState() => _TeethConditionWidgetState();
}

class _TeethConditionWidgetState extends State<TeethConditionWidget> {
  late List<Map<String, String>> _localTeethData;
  late final List<Map<String, TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _localTeethData =
        widget.teethData.map((item) => Map<String, String>.from(item)).toList();
    _controllers = _localTeethData
        .map(
          (item) => {
            'topLeft': TextEditingController(text: item['topLeft']),
            'topRight': TextEditingController(text: item['topRight']),
            'bottomLeft': TextEditingController(text: item['bottomLeft']),
            'bottomRight': TextEditingController(text: item['bottomRight']),
          },
        )
        .toList();
  }

  @override
  void dispose() {
    for (final controllerMap in _controllers) {
      for (final controller in controllerMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _updateTeethData(int crossIndex, String quadrant, String value) {
    _localTeethData[crossIndex][quadrant] = value;
    widget.onChanged(_localTeethData);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services,
                color: tokens.iconMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '牙齿情况',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildCrossWidget(0)),
              const SizedBox(width: 4),
              Expanded(child: _buildCrossWidget(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCrossWidget(int crossIndex) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Container(
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '牙位 ${crossIndex + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: colors.onSurface,
              ),
            ),
          ),
          Expanded(child: _buildCross(crossIndex)),
        ],
      ),
    );
  }

  Widget _buildCross(int crossIndex) {
    final tokens = context.tokens;
    final crossLineColor = tokens.primaryAccent.withValues(alpha: 0.72);

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Stack(
        children: [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              height: 2.2,
              decoration: BoxDecoration(
                color: crossLineColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 2.2,
              height: 50,
              decoration: BoxDecoration(
                color: crossLineColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuadrantTextField(
                            crossIndex,
                            'topLeft',
                            TextAlign.right,
                            const EdgeInsets.only(right: 4, top: 18),
                          ),
                        ),
                        Expanded(
                          child: _buildQuadrantTextField(
                            crossIndex,
                            'topRight',
                            TextAlign.left,
                            const EdgeInsets.only(left: 4, top: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuadrantTextField(
                            crossIndex,
                            'bottomLeft',
                            TextAlign.right,
                            const EdgeInsets.only(right: 4, bottom: 18),
                          ),
                        ),
                        Expanded(
                          child: _buildQuadrantTextField(
                            crossIndex,
                            'bottomRight',
                            TextAlign.left,
                            const EdgeInsets.only(left: 4, bottom: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantTextField(
    int crossIndex,
    String quadrant,
    TextAlign textAlign,
    EdgeInsets contentPadding,
  ) {
    return TextField(
      controller: _controllers[crossIndex][quadrant],
      decoration: InputDecoration(
        contentPadding: contentPadding,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: '',
        hintStyle: const TextStyle(fontSize: 0),
        isDense: true,
        filled: false,
      ),
      textAlign: textAlign,
      style: TextStyle(fontSize: 12, color: context.colors.onSurface),
      cursorColor: context.tokens.primaryAccent.withValues(alpha: 0.5),
      maxLines: 1,
      onChanged: (value) => _updateTeethData(crossIndex, quadrant, value),
    );
  }
}
