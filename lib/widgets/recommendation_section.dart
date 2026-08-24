import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_info.dart';
import '../services/theme_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import 'video_card.dart';
import 'video_menu_bottom_sheet.dart';
import 'shimmer_effect.dart';
import 'tv_focus_grid.dart';

/// 推荐信息模块组件
class RecommendationSection extends StatefulWidget {
  final String title; // 标题
  final String? moreText; // 查看更多文本
  final VoidCallback? onMoreTap; // 查看更多点击回调
  final List<VideoInfo>? videoInfos; // 视频信息列表
  final Function(VideoInfo)? onItemTap; // 项目点击回调
  final Function(VideoInfo, VideoMenuAction)? onGlobalMenuAction; // 全局菜单操作回调
  final bool isLoading; // 是否加载中
  final bool hasError; // 是否有错误
  final VoidCallback? onRetry; // 重试回调
  final double cardCount; // 显示的卡片数量（如2.75）
  final Map<String, String>? rateMap; // 评分映射，key为item.id，value为评分

  const RecommendationSection({
    super.key,
    required this.title,
    this.moreText,
    this.onMoreTap,
    this.videoInfos,
    this.onItemTap,
    this.onGlobalMenuAction,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.cardCount = 2.75,
    this.rateMap,
  });

  @override
  State<RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前使用的数据列表
    final currentItems = widget.videoInfos ?? [];

    // 如果没有数据且不在加载中，隐藏组件
    if (!widget.isLoading && currentItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和查看更多按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Consumer<ThemeService>(
                  builder: (context, themeService, child) {
                    return Text(
                      widget.title,
                      style: FontUtils.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeService.isDarkMode
                            ? const Color(0xFFffffff)
                            : const Color(0xFF2c3e50),
                      ),
                    );
                  },
                ),
                if (widget.moreText != null && widget.onMoreTap != null)
                  TextButton(
                    onPressed: widget.onMoreTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      overlayColor: Colors.transparent,
                    ),
                    child: Text(
                      widget.moreText!,
                      style: FontUtils.poppins(
                        fontSize: 14,
                        color: const Color(0xFF7f8c8d),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 内容区域
          if (widget.isLoading)
            _buildLoadingState()
          else if (widget.hasError)
            _buildErrorState()
          else
            _buildContentTVOS(),
        ],
      ),
    );
  }

  /// 构建 tvOS 内容区域（用 TVFocusGrid 包裹）
  Widget _buildContentTVOS() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double visibleCards = DeviceUtils.getHorizontalVisibleCards(context, widget.cardCount);
        final double screenWidth = constraints.maxWidth;
        const double padding = 32.0;
        const double spacing = 12.0;
        final double availableWidth = screenWidth - padding;
        const double minCardWidth = 120.0;
        final double calculatedCardWidth =
            (availableWidth - (spacing * (visibleCards - 1))) / visibleCards;
        final double cardWidth = math.max(calculatedCardWidth, minCardWidth);

        return TVFocusGrid(
          child: SizedBox(
            height: (cardWidth * 1.5) + 60,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.none,
              itemCount: widget.videoInfos?.length ?? 0,
              itemBuilder: (context, index) {
                final videoInfo = widget.videoInfos![index];
                return Container(
                  margin: EdgeInsets.only(
                    right: index < widget.videoInfos!.length - 1 ? spacing : 0,
                  ),
                  child: VideoCard(
                    videoInfo: videoInfo,
                    onTap: () => widget.onItemTap?.call(videoInfo),
                    from: videoInfo.source == 'douban'
                        ? 'douban'
                        : (videoInfo.source == 'bangumi'
                            ? 'bangumi'
                            : 'playrecord'),
                    cardWidth: cardWidth,
                    onGlobalMenuAction: widget.onGlobalMenuAction != null
                        ? (action) =>
                            widget.onGlobalMenuAction!(videoInfo, action)
                        : null,
                    isFavorited: false,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据宽度动态展示卡片数：平板模式 5.75/6.75/7.75，手机模式使用传入的cardCount
        final double visibleCards = DeviceUtils.getHorizontalVisibleCards(context, widget.cardCount);
        final int skeletonCount = visibleCards.ceil(); // 骨架卡片数量

        // 计算卡片宽度
        final double screenWidth = constraints.maxWidth;
        const double padding = 32.0; // 左右padding (16 * 2)
        const double spacing = 12.0; // 卡片间距
        final double availableWidth = screenWidth - padding;
        // 确保最小宽度，防止负宽度约束
        const double minCardWidth = 120.0; // 最小卡片宽度
        final double calculatedCardWidth =
            (availableWidth - (spacing * (visibleCards - 1))) / visibleCards;
        final double cardWidth = math.max(calculatedCardWidth, minCardWidth);

        return Container(
          height: (cardWidth * 1.5) + 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: skeletonCount,
            itemBuilder: (context, index) {
              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(
                  right: index < skeletonCount - 1 ? spacing : 0,
                ),
                child: _buildSkeletonCard(cardWidth),
              );
            },
          ),
        );
      },
    );
  }

  /// 构建骨架卡片
  Widget _buildSkeletonCard(double width) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final double height = width * 1.5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 封面骨架
            ShimmerEffect(
              width: width,
              height: height,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            // 标题骨架
            Center(
              child: ShimmerEffect(
                width: width * 0.8,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建错误状态
  Widget _buildErrorState() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '加载失败',
              style: FontUtils.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onRetry,
                child: Text(
                  '重试',
                  style: FontUtils.poppins(
                    fontSize: 12,
                    color: const Color(0xFF2c3e50),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
