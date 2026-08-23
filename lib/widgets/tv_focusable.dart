import 'package:flutter/material.dart';

/// Apple TV Focus 高亮通用包裹组件
/// 当获得焦点时：放大 + 白色边框 + 阴影
class TVFocusableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final double scale;
  final Color borderColor;
  final double borderWidth;
  final Duration animationDuration;
  final FocusNode? focusNode;
  final bool enabled;

  const TVFocusableWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onMenu,
    this.scale = 1.08,
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.animationDuration = const Duration(milliseconds: 150),
    this.focusNode,
    this.enabled = true,
  });

  @override
  State<TVFocusableWidget> createState() => _TVFocusableWidgetState();
}

class _TVFocusableWidgetState extends State<TVFocusableWidget> {
  late FocusNode _node;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode(debugLabel: 'tv_focusable');
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final focused = _node.hasFocus;
    if (focused != _isFocused) {
      setState(() {
        _isFocused = focused;
      });
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      canRequestFocus: widget.enabled,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          // Menu 按钮触发 context menu
          if (event.logicalKey == LogicalKeyboardKey.goBack) {
            widget.onMenu?.call();
            return KeyEventResult.handled;
          }
          // Select 按钮触发点击
          if (event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? widget.scale : 1.0,
        duration: widget.animationDuration,
        child: AnimatedContainer(
          duration: widget.animationDuration,
          decoration: BoxDecoration(
            border: Border.all(
              color: _isFocused ? widget.borderColor : Colors.transparent,
              width: _isFocused ? widget.borderWidth : 0,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.borderColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
