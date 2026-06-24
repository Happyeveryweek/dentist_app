import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

/// 全局Toast提示工具
class ToastUtil {
  // 单例模式
  static final ToastUtil _instance = ToastUtil._internal();
  factory ToastUtil() => _instance;
  ToastUtil._internal();

  // 当前显示的OverlayEntry
  static OverlayEntry? _currentOverlay;

  /// 显示一个成功消息
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      AppTheme.successColor,
      Icons.check_circle_outline,
      const Duration(seconds: 2),
    );
  }

  /// 显示一个错误消息
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      AppTheme.errorColor,
      Icons.error_outline,
      const Duration(seconds: 3),
    );
  }

  /// 显示一个信息消息
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      AppTheme.infoColor,
      Icons.info_outline,
      const Duration(seconds: 2),
    );
  }

  /// 显示一个消息
  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
    Duration duration,
  ) {
    // 移除当前显示的消息（如果有）
    _hideOverlay();

    // 创建一个新的OverlayEntry
    final overlay = OverlayEntry(
      builder:
          (context) => _ToastWidget(message: message, color: color, icon: icon),
    );

    // 保存当前OverlayEntry
    _currentOverlay = overlay;

    // 显示Overlay
    Overlay.of(context).insert(overlay);

    // 设置自动关闭
    Future.delayed(duration, () {
      _hideOverlay();
    });
  }

  /// 隐藏当前显示的消息
  static void _hideOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// Toast消息小部件
class _ToastWidget extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _ToastWidget({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  _ToastWidgetState createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 创建动画
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    // 开始动画
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 50.0,
      left: 15.0,
      right: 15.0,
      child: FadeTransition(
        opacity: _animation,
        child: Material(
          elevation: 10.0,
          borderRadius: BorderRadius.circular(10.0),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              border: Border.all(color: widget.color.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: widget.color, size: 24.0),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.black87, fontSize: 16.0),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ToastUtil._hideOverlay();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: widget.color, size: 18.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
