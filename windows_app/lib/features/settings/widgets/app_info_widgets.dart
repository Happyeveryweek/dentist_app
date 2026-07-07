import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class InfoSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? action;
  final List<Widget> children;

  const InfoSectionCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    this.action,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final actionWidget = action;
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              if (actionWidget != null) actionWidget,
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class StatusRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool isFilePath;

  const StatusRow({
    Key? key,
    required this.label,
    this.value,
    this.valueWidget,
    this.isFilePath = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final valueWidgetLocal = valueWidget;
    final tokens = context.tokens;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tokens.iconMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        if (valueWidgetLocal != null)
          valueWidgetLocal
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.mutedBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.border),
            ),
            child: SelectableText(
              value ?? '-',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface,
                fontFamily: isFilePath ? 'monospace' : null,
              ),
            ),
          ),
      ],
    );
  }
}

class ToolStatusChip extends StatelessWidget {
  final String label;
  final bool isAvailable;

  const ToolStatusChip(
      {Key? key, required this.label, required this.isAvailable})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Icon(
          isAvailable ? Icons.check_circle : Icons.error,
          color: isAvailable ? tokens.success : tokens.error,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isAvailable ? tokens.success : tokens.error,
          ),
        )
      ],
    );
  }
}

class StatBox extends StatelessWidget {
  final String label;
  final String value;

  const StatBox({Key? key, required this.label, required this.value})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: TextStyle(fontSize: 11, color: tokens.iconMuted)),
        ],
      ),
    );
  }
}
