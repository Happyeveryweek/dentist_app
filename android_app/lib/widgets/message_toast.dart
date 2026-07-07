import 'package:flutter/material.dart';

/// 自定义消息提示组件
class MessageToast extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final Duration duration;
  final VoidCallback? onDismiss;

  const MessageToast({
    super.key,
    required this.message,
    required this.isSuccess,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<MessageToast> createState() => _MessageToastState();
}

class _MessageToastState extends State<MessageToast>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double> _fadeAnimation = const AlwaysStoppedAnimation<double>(1.0);
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation<Offset>(Offset.zero);
  Animation<double> _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    final controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _controller = controller;

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // 改为从底部滑入
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _showToast();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _showToast() {
    setState(() {
      _isVisible = true;
    });

    _controller?.forward().then((_) {
      Future.delayed(widget.duration, () {
        if (mounted && _isVisible) {
          _hideToast();
        }
      });
    });
  }

  void _hideToast() {
    _controller?.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 100, // 改为底部显示，适合登录页面
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      widget.isSuccess
                          ? [
                            const Color(0xFF4CAF50),
                            const Color(0xFF66BB6A),
                            const Color(0xFF81C784),
                          ]
                          : [
                            const Color(0xFFF44336),
                            const Color(0xFFEF5350),
                            const Color(0xFFE57373),
                          ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isSuccess ? Colors.green : Colors.red)
                        .withValues(alpha: 0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // 状态图标容器
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 18),

                  // 消息文本
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 关闭按钮
                  GestureDetector(
                    onTap: _hideToast,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示消息提示的便捷方法
class MessageToastHelper {
  static void showSuccess(BuildContext context, String message) {
    _showMessage(context, message, true);
  }

  static void showError(BuildContext context, String message) {
    _showMessage(context, message, false);
  }

  static void _showMessage(
    BuildContext context,
    String message,
    bool isSuccess,
  ) {
    final overlay = Overlay.of(context);
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder:
          (context) => MessageToast(
            message: message,
            isSuccess: isSuccess,
            onDismiss: () {
              overlayEntry?.remove();
            },
          ),
    );

    overlay.insert(overlayEntry);
  }
}
