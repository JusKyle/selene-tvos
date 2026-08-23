import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tv_focusable.dart';
import 'tv_focus_grid.dart';

/// tvOS 全屏菜单面板
///
/// 用于替代 showModalBottomSheet / showDialog 在全屏场景下的使用。
/// 提供：
/// - 全屏半透明深色背景（0.85 不透明度）
/// - 顶部居中标题 + 右侧 Focus 关闭按钮
/// - 垂直滚动 Focus 列表（item 建议用 [TVFocusableWidget] 包裹，未包裹的会自动包裹）
/// - Menu/返回键关闭面板
class TVFullscreenPanel extends StatelessWidget {
  final String title;

  /// 面板内容列表，每个 item 建议用 [TVFocusableWidget] 包裹
  final List<Widget> items;

  /// 关闭面板时的回调（Menu 键 / 关闭按钮触发）
  final VoidCallback? onClose;

  /// 列表内容最大宽度，超宽屏幕（如 TV）下居中显示更美观
  final double maxContentWidth;

  const TVFullscreenPanel({
    super.key,
    required this.title,
    required this.items,
    this.onClose,
    this.maxContentWidth = 720,
  });

  /// 以全屏路由方式展示面板
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<Widget> items,
    VoidCallback? onClose,
  }) {
    return Navigator.of(context).push(PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TVFullscreenPanel(
          title: title,
          items: items,
          onClose: onClose,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ));
  }

  void _close(BuildContext context) {
    onClose?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 确保每个 item 都可聚焦，且 Menu/返回键默认关闭面板。
  ///
  /// TVFocusableWidget 会无条件消费 goBack 键（即使 onMenu 为 null），
  /// 因此这里为没有设置 onMenu 的 item 注入默认的关闭回调，
  /// 保证焦点在任意 item 上时按下 Menu 都能返回上一页。
  Widget _wrapItem(BuildContext context, Widget item) {
    if (item is TVFocusableWidget) {
      if (item.onMenu != null) return item;
      return TVFocusableWidget(
        key: item.key,
        onTap: item.onTap,
        onMenu: () => _close(context),
        scale: item.scale,
        borderColor: item.borderColor,
        borderWidth: item.borderWidth,
        animationDuration: item.animationDuration,
        focusNode: item.focusNode,
        enabled: item.enabled,
        autofocus: item.autofocus,
        child: item.child,
      );
    }
    return TVFocusableWidget(
      onMenu: () => _close(context),
      child: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withValues(alpha: 0.85),
          child: SafeArea(
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.goBack ||
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    _close(context);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxContentWidth,
                        ),
                        child: TVFocusGrid(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _wrapItem(context, items[index]);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Positioned(
            right: 12,
            child: TVFocusableWidget(
              onTap: () => _close(context),
              onMenu: () => _close(context),
              borderColor: Colors.white,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
