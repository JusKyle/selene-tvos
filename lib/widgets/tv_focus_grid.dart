import 'package:flutter/material.dart';

/// Apple TV 网格 Focus 导航策略
/// 确保方向键按视觉顺序（从上到下，从左到右）导航
class TVGridFocusTraversal extends OrderFocusTraversalPolicy {
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants, {
    FocusNode? currentNode,
  }) {
    final sorted = descendants.toList()
      ..sort((a, b) {
        final aRect = _getRect(a);
        final bRect = _getRect(b);
        final cmp = aRect.top.compareTo(bRect.top);
        return cmp != 0 ? cmp : aRect.left.compareTo(bRect.left);
      });
    return sorted;
  }

  Rect _getRect(FocusNode node) {
    final renderBox = node.context?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Rect.zero;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }
}

/// 用于 tvOS 平台包裹 GridView / ListView 的辅助组件
/// 自动应用 TVGridFocusTraversal 导航策略
class TVFocusGrid extends StatelessWidget {
  final Widget child;

  const TVFocusGrid({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      order: TVGridFocusTraversal(),
      child: child,
    );
  }
}
