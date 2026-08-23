import 'package:flutter/material.dart';

/// A wrapper widget that highlights focused children on tvOS/Apple TV.
///
/// Focusable widgets gain a colored border and slight scale when focused,
/// making them easy to spot with the Siri Remote.
///
/// This is a stub that other teams will complete. Provide a [child] and
/// callbacks for [onTap] (select) and [onMenu].
class TVFocusableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final double scale;
  final Color borderColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final FocusTraversalPolicy? focusTraversalPolicy;

  const TVFocusableWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onMenu,
    this.scale = 1.08,
    this.borderColor = Colors.white,
    this.focusNode,
    this.autofocus = false,
    this.focusTraversalPolicy,
  });

  @override
  State<TVFocusableWidget> createState() => _TVFocusableWidgetState();
}

class _TVFocusableWidgetState extends State<TVFocusableWidget> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      focusTraversalPolicy: widget.focusTraversalPolicy,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onMenu?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (context, child) {
          final hasFocus = _focusNode.hasFocus;
          return Transform.scale(
            scale: hasFocus ? widget.scale : 1.0,
            child: Container(
              decoration: hasFocus
                  ? BoxDecoration(
                      border: Border.all(color: widget.borderColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
