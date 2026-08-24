import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/video_info.dart';
import '../services/theme_service.dart';
import 'video_menu_bottom_sheet.dart';
import '../utils/image_url.dart';
import '../models/search_result.dart';
import '../utils/font_utils.dart';
import 'tv_focusable.dart';

/// 视频卡片组件
class VideoCard extends StatefulWidget {
  final VideoInfo videoInfo;
  final VoidCallback? onTap;
  final String from; // 场景值：'favorite', 'playrecord', 'search', 'agg'
  final double? cardWidth; // 卡片宽度，用于响应式布局
  final Function(VideoMenuAction)? onGlobalMenuAction; // 视频菜单操作回调
  final bool isFavorited; // 是否已收藏
  final List<SearchResult>? originalResults;
  final Function(SearchResult)? onSourceSelected;

  const VideoCard({
    super.key,
    required this.videoInfo,
    this.onTap,
    this.from = 'playrecord',
    this.cardWidth,
    this.onGlobalMenuAction,
    this.isFavorited = false,
    this.originalResults,
    this.onSourceSelected,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        // 使用传入的宽度或默认宽度
        final double width = widget.cardWidth ?? 120.0;
        final double height = width * 1.5; // 2:3 比例

        // 缓存计算结果
        final bool shouldShowEpisodeInfo = _shouldShowEpisodeInfo();
        final bool shouldShowProgress = _shouldShowProgress();
        final String episodeText =
            shouldShowEpisodeInfo ? _getEpisodeText() : '';

        return FutureBuilder<String>(
          future: getImageUrl(widget.videoInfo.cover, widget.videoInfo.source),
          builder: (context, snapshot) {
            final String imageUrl = snapshot.data ?? widget.videoInfo.cover;
            final headers =
                getImageRequestHeaders(imageUrl, widget.videoInfo.source);

            final cardContent = SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 封面图片和进度指示器
                  Stack(
                    children: [
                      // 封面图片
                      Container(
                        width: width,
                        height: height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            // 使用图片URL作为缓存key
                            cacheKey: imageUrl,
                            httpHeaders: headers,
                            // 添加缓存配置
                            memCacheWidth: (width *
                                    MediaQuery.of(context).devicePixelRatio)
                                .round(),
                            memCacheHeight: (height *
                                    MediaQuery.of(context).devicePixelRatio)
                                .round(),
                            // 占位符
                            placeholder: (context, url) => Container(
                              width: width,
                              height: height,
                              decoration: BoxDecoration(
                                color: themeService.isDarkMode
                                    ? const Color(0xFF333333)
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            // 错误占位符
                            errorWidget: (context, url, error) => Container(
                              color: themeService.isDarkMode
                                  ? const Color(0xFF333333)
                                  : Colors.grey[300],
                              child: Icon(
                                Icons.movie,
                                color: themeService.isDarkMode
                                    ? const Color(0xFF666666)
                                    : Colors.grey,
                                size: 40,
                              ),
                            ),
                            // 图片淡入动画
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 100),
                          ),
                        ),
                      ),
                      // 年份徽章（搜索模式和聚合模式）
                      if ((widget.from == 'search' || widget.from == 'agg') &&
                          widget.videoInfo.year.isNotEmpty &&
                          widget.videoInfo.year != 'unknown')
                        Positioned(
                          top: 4,
                          left: 4,
                          child: AnimatedScale(
                            scale: _isFocused ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2c3e50)
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                widget.videoInfo.year,
                                style: FontUtils.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 集数指示器或评分指示器
                      if ((widget.from == 'douban' ||
                              widget.from == 'bangumi') &&
                          _shouldShowRating())
                        Positioned(
                          top: 4,
                          right: 4,
                          child: AnimatedScale(
                            scale: _isFocused ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Color(0xFFe91e63), // 粉色圆形背景
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  widget.videoInfo.rate!,
                                  style: FontUtils.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (shouldShowEpisodeInfo)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: AnimatedScale(
                            scale: _isFocused ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27ae60),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                episodeText,
                                style: FontUtils.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 进度条
                      if (shouldShowProgress)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: widget.videoInfo.progressPercentage,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFF27ae60),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 标题和源名称容器，确保居中对齐
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 标题
                        Text(
                          widget.videoInfo.title,
                          style: FontUtils.poppins(
                            fontSize: (width < 100 ? 12 : 13) + (_isFocused ? 2 : 0),
                            fontWeight: FontWeight.w500,
                            color: _isFocused
                                ? Colors.green
                                : (themeService.isDarkMode
                                    ? const Color(0xFFffffff)
                                    : const Color(0xFF2c3e50)),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: widget.from == 'douban'
                              ? 2
                              : 1, // 豆瓣模式允许两行，其他模式一行
                          overflow: TextOverflow.ellipsis,
                        ),
                        // 豆瓣模式和Bangumi模式不显示来源信息
                        if (widget.from != 'douban' &&
                            widget.from != 'bangumi' &&
                            widget.from != 'agg') ...[
                          const SizedBox(height: 3), // 增加title和sourceName之间的间距
                          // 视频源名称
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: width < 100 ? 2 : 4,
                              vertical: 2.0, // 增加垂直padding，让border不紧贴文字
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isFocused
                                    ? Colors.green
                                    : const Color(0xFF7f8c8d),
                                width: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              widget.from == 'agg'
                                  ? _getAggregatedSourceText(
                                      widget.videoInfo.sourceName)
                                  : widget.videoInfo.sourceName,
                              style: FontUtils.poppins(
                                fontSize:
                                    width < 100 ? 11 : 12, // 根据宽度调整字体大小，调大字体
                                color: _isFocused
                                    ? Colors.green
                                    : (widget.from == 'agg'
                                        ? const Color(0xFF9b59b6)
                                        : const Color(0xFF7f8c8d)),
                                height: 1.0, // 进一步减少行高
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );

            // tvOS 平台：使用 TVFocusableWidget 包裹
            return TVFocusableWidget(
              onTap: widget.onTap,
              onMenu: () {
                if (widget.from == 'playrecord' ||
                    widget.from == 'douban' ||
                    widget.from == 'bangumi' ||
                    widget.from == 'favorite' ||
                    widget.from == 'search' ||
                    widget.from == 'agg') {
                  _showGlobalMenu(context);
                }
              },
              child: Focus(
                onFocusChange: (focused) {
                  setState(() {
                    _isFocused = focused;
                  });
                },
                child: AnimatedScale(
                  scale: _isFocused ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  child: cardContent,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 根据场景判断是否显示集数信息
  bool _shouldShowEpisodeInfo() {
    // 豆瓣模式和Bangumi模式不显示集数信息
    if (widget.from == 'douban' || widget.from == 'bangumi') {
      return false;
    }

    // 总集数为1时永远不显示集数指示器
    if (widget.videoInfo.totalEpisodes <= 1) {
      return false;
    }

    switch (widget.from) {
      case 'favorite':
        return true;
      case 'playrecord':
        return true;
      case 'search':
        return true;
      case 'agg':
        return true;
      default:
        return true;
    }
  }

  /// 获取集数显示文本
  String _getEpisodeText() {
    switch (widget.from) {
      case 'favorite':
        // 收藏夹：如果有播放记录（index > 0）显示 x/y，否则只显示总集数
        return widget.videoInfo.index > 0
            ? '${widget.videoInfo.index}/${widget.videoInfo.totalEpisodes}'
            : '${widget.videoInfo.totalEpisodes}';
      case 'playrecord':
        return '${widget.videoInfo.index}/${widget.videoInfo.totalEpisodes}'; // 播放记录显示当前/总集数
      case 'search':
        return '${widget.videoInfo.totalEpisodes}'; // 搜索模式只显示总集数
      case 'agg':
        return '${widget.videoInfo.totalEpisodes}'; // 聚合模式只显示总集数
      default:
        return '${widget.videoInfo.index}/${widget.videoInfo.totalEpisodes}'; // 默认显示当前/总集数
    }
  }

  /// 根据场景判断是否显示进度条
  bool _shouldShowProgress() {
    switch (widget.from) {
      case 'favorite':
        return false; // 收藏夹中不显示进度条
      case 'douban':
        return false; // 豆瓣模式不显示进度条
      case 'bangumi':
        return false; // Bangumi模式不显示进度条
      case 'search':
        return false; // 搜索模式不显示进度条
      case 'agg':
        return false; // 聚合模式不显示进度条
      case 'playrecord':
      default:
        return true; // 播放记录中显示进度条
    }
  }

  /// 判断是否应该显示评分
  bool _shouldShowRating() {
    // 评分为空或null时不显示
    if (widget.videoInfo.rate == null || widget.videoInfo.rate!.isEmpty) {
      return false;
    }

    // 尝试解析评分为数字，如果为0或解析失败则不显示
    try {
      final rating = double.parse(widget.videoInfo.rate!);
      return rating > 0;
    } catch (e) {
      // 如果评分不是数字格式，则不显示
      return false;
    }
  }

  /// 获取聚合源文本显示
  String _getAggregatedSourceText(String sourceNames) {
    final sources = sourceNames.split(', ');
    if (sources.length <= 2) {
      return sourceNames;
    } else {
      return '${sources.take(2).join(', ')}等${sources.length}源';
    }
  }

  /// 显示视频菜单
  void _showGlobalMenu(BuildContext context) {
    if (widget.onGlobalMenuAction != null) {
      VideoMenuBottomSheet.show(
        context,
        videoInfo: widget.videoInfo,
        isFavorited: widget.isFavorited,
        onActionSelected: widget.onGlobalMenuAction!,
        from: widget.from,
        originalResults: widget.originalResults,
        onSourceSelected: widget.onSourceSelected,
      );
    }
  }
}
