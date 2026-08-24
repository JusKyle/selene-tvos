import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/video_player_widget.dart';
import '../models/live_channel.dart';
import '../models/live_source.dart';
import '../models/epg_program.dart';
import '../services/live_service.dart';
import '../utils/font_utils.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';
import '../widgets/switch_loading_overlay.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_focus_grid.dart';

class LivePlayerScreen extends StatefulWidget {
  final LiveChannel channel;
  final LiveSource source;

  const LivePlayerScreen({
    super.key,
    required this.channel,
    required this.source,
  });

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen>
    with TickerProviderStateMixin {
  late SystemUiOverlayStyle _originalStyle;
  bool _isInitialized = false;
  late LiveChannel _currentChannel;
  late LiveSource _currentSource;
  List<EpgProgram>? _programs;
  bool _isLoadingEpg = false;
  int _epgLoadGeneration = 0; // 防止快速切台时旧 EPG 覆盖新频道
  List<LiveChannel> _allChannels = [];
  String _selectedGroup = '全部';

  // 播放器的 GlobalKey
  final GlobalKey _playerKey = GlobalKey();

  // 当前节目的 GlobalKey，用于滚动定位
  final GlobalKey _currentProgramKey = GlobalKey();

  // 当前频道的 GlobalKey，用于滚动定位
  final GlobalKey _currentChannelKey = GlobalKey();

  // 节目单滚动控制器（横向）
  final ScrollController _programScrollController = ScrollController();

  // 频道列表滚动控制器
  final ScrollController _channelScrollController = ScrollController();

  // 加载状态
  bool _isLoading = true;
  String _loadingMessage = '正在加载直播频道...';
  late AnimationController _loadingAnimationController;

  // tvOS：半透明覆盖层频道面板是否显示
  bool _showTVChannelPanel = true;
  // tvOS：当前频道条目的 FocusNode，用于面板显示/重新显示时获得焦点
  final FocusNode _tvCurrentChannelFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentSource = widget.source;

    // 初始化动画控制器
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      // 保存当前的系统UI样式
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      _originalStyle = SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      );
      _isInitialized = true;

      // 加载数据
      _loadAllChannels();
      _loadEpgData();

      // tvOS：等待控件挂载后，让当前频道条目获得焦点（晚于 TVPlayerControls 的 autofocus）
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _showTVChannelPanel) {
          _tvCurrentChannelFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _loadAllChannels() async {
    try {
      final channels = await LiveService.getLiveChannels(_currentSource.key);
      if (mounted) {
        setState(() {
          _allChannels = channels;
        });

        // 滚动到当前频道
        _scrollToCurrentChannelTV();
      }
    } catch (e) {
      debugPrint('加载频道列表失败: $e');
      if (mounted) {
        setState(() {
          _allChannels = [];
        });
      }
    }
  }

  void _switchChannel(LiveChannel channel) {
    setState(() {
      _currentChannel = channel;
      _isLoading = true;
      _loadingMessage = '切换频道...';
    });

    // 重新加载 EPG
    _loadEpgData();

    // 滚动到当前频道
    _scrollToCurrentChannelTV();
  }

  @override
  void dispose() {
    // 恢复原始的系统UI样式
    SystemChrome.setSystemUIOverlayStyle(_originalStyle);
    _programScrollController.dispose();
    _channelScrollController.dispose();
    _loadingAnimationController.dispose();
    _tvCurrentChannelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEpgData() async {
    if (!mounted) return;
    final generation = ++_epgLoadGeneration;

    setState(() {
      _isLoadingEpg = true;
    });

    try {
      // 如果 tvgId 为空，则不加载 EPG
      if (_currentChannel.tvgId.isEmpty) {
        if (mounted && generation == _epgLoadGeneration) {
          setState(() {
            _programs = null;
            _isLoadingEpg = false;
          });
        }
        return;
      }

      // 调用 LiveService 获取 EPG 数据
      final epgData = await LiveService.getLiveEpg(
        _currentChannel.tvgId,
        _currentSource.key,
      );

      // 快速切台时丢弃过期的响应
      if (mounted && generation == _epgLoadGeneration) {
        setState(() {
          _programs = epgData?.programs;
          _isLoadingEpg = false;
        });

        // 滚动到当前节目
        _scrollToCurrentProgram();
      }
    } catch (e) {
      debugPrint('加载 EPG 失败: $e');
      if (mounted && generation == _epgLoadGeneration) {
        setState(() {
          _programs = null;
          _isLoadingEpg = false;
        });
      }
    }
  }

  /// 处理视频播放器 ready 事件
  void _onVideoPlayerReady() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 滚动到当前正在播放的节目（横向列表）
  void _scrollToCurrentProgram() {
    if (_programs == null || _programs!.isEmpty) {
      return;
    }

    // 找到当前正在播放的节目索引
    final currentIndex = _programs!.indexWhere((p) => p.isLive);
    if (currentIndex == -1) {
      return;
    }

    // 延迟执行，确保列表已经渲染
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (!_programScrollController.hasClients) {
        return;
      }

      // 根据最大滚动范围反推实际的卡片宽度
      // maxScrollExtent = 总宽度 - 可视区域宽度
      final viewportWidth = _programScrollController.position.viewportDimension;
      final totalContentWidth =
          _programScrollController.position.maxScrollExtent + viewportWidth;
      final actualItemWidth = totalContentWidth / _programs!.length;

      // 计算卡片左边缘的位置
      final itemLeftPosition = currentIndex * actualItemWidth;

      // 将卡片居中：卡片左边缘位置 - (可视区域宽度 / 2) + (卡片宽度 / 2)
      final centerOffset =
          itemLeftPosition - (viewportWidth / 2) + (actualItemWidth / 2);

      // 确保不会滚动到负值或超出最大滚动范围
      final maxScrollExtent = _programScrollController.position.maxScrollExtent;
      final clampedOffset = centerOffset.clamp(0.0, maxScrollExtent);

      // 滚动到目标位置
      _programScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// tvOS：滚动到当前频道（基于 GlobalKey + ensureVisible，适配 tvOS 面板列表）
  void _scrollToCurrentChannelTV() {
    if (_allChannels.isEmpty) return;
    final filteredChannels = _getFilteredChannels();
    if (filteredChannels.isEmpty) return;
    final currentIndex =
        filteredChannels.indexWhere((c) => c.id == _currentChannel.id);
    if (currentIndex == -1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentChannelKey.currentContext == null) return;
      Scrollable.ensureVisible(
        _currentChannelKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final themeService = context.watch<ThemeService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor:
            isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: isDarkMode
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFe6f3fb),
                      Color(0xFFeaf3f7),
                      Color(0xFFf7f7f3),
                      Color(0xFFe9ecef),
                      Color(0xFFdbe3ea),
                      Color(0xFFd3dde6),
                    ],
                    stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
                  ),
            color: isDarkMode ? theme.scaffoldBackgroundColor : null,
          ),
          child: _buildTVFocusGate(
            Stack(
              children: [
                // tvOS：半透明覆盖层频道面板
                _buildTVChannelPanel(theme, themeService),
                // 全屏播放器层
                _buildPlayerLayer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建播放器层
  Widget _buildPlayerLayer() {
    // tvOS：全屏播放器层，包一层按键处理（方向键显示频道面板）
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: _buildTVPlayerKeyHandle(
        Stack(
          children: [
            Container(
              key: _playerKey,
              color: Colors.black,
              child: _buildPlayerWidget(),
            ),
            // 加载蒙版
            _buildSwitchLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  /// 构建播放器组件
  Widget _buildPlayerWidget() {
    final videoUrl = _currentChannel.url;

    return VideoPlayerWidget(
      key: ValueKey(_currentChannel.id),
      url: videoUrl,
      headers: <String, String>{
        'User-Agent': _currentSource.ua.isNotEmpty
            ? _currentSource.ua
            : 'AptvPlayer/1.4.10',
      },
      videoTitle: _currentChannel.name,
      onBackPressed: () => Navigator.pop(context),
      onReady: _onVideoPlayerReady,
      live: true,
    );
  }

  // ---- tvOS 分支 ----

  /// tvOS：焦点门卫。包一层 FocusTraversalGroup 串联播放器与频道面板
  Widget _buildTVFocusGate(Widget child) {
    return TVFocusGrid(child: child);
  }

  /// tvOS：播放器按键处理。焦点在播放器上时，方向键显示频道面板并聚焦当前频道
  Widget _buildTVPlayerKeyHandle(Widget playerLayer) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _showTVChannelPanel = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tvCurrentChannelFocusNode.requestFocus();
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: playerLayer,
    );
  }

  /// tvOS：半透明覆盖层频道面板（全屏播放器 + 右侧频道列表）
  Widget _buildTVChannelPanel(ThemeData theme, ThemeService themeService) {
    if (!_showTVChannelPanel) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final double panelWidth = (screenWidth * 0.30).clamp(360.0, 520.0);

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: panelWidth,
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：当前频道信息
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentChannel.name,
                    style: FontUtils.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currentSource.name} > ${_currentChannel.group}',
                    style: FontUtils.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // EPG 节目单
            _buildTVProgramSection(themeService),
            // 频道列表（占据剩余空间）
            Expanded(
              child: _buildTVChannelList(themeService),
            ),
          ],
        ),
      ),
    );
  }

  /// tvOS：EPG 节目单区块（横向滚动 + Focus 导航）
  Widget _buildTVProgramSection(ThemeService themeService) {
    return Container(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '节目单',
              style: FontUtils.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          _buildTVProgramList(themeService),
        ],
      ),
    );
  }

  /// tvOS：横向节目单列表，每个节目项用 TVFocusableWidget 包裹
  Widget _buildTVProgramList(ThemeService themeService) {
    if (_isLoadingEpg) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text(
            '加载中...',
            style: FontUtils.poppins(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ),
      );
    }

    if (_programs == null || _programs!.isEmpty) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text(
            '暂无节目单信息',
            style: FontUtils.poppins(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 88,
      child: ListView.builder(
        controller: _programScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _programs!.length,
        itemBuilder: (context, index) {
          final program = _programs![index];
          return _buildTVProgramItem(
            program,
            themeService,
            key: program.isLive ? _currentProgramKey : null,
          );
        },
      ),
    );
  }

  Widget _buildTVProgramItem(
    EpgProgram program,
    ThemeService themeService, {
    Key? key,
  }) {
    final now = DateTime.now();
    final isLive = program.isLive;
    final isPast = now.isAfter(program.endTime);

    Color backgroundColor;
    Color textColor;
    if (isLive) {
      backgroundColor = const Color(0xFF27ae60).withValues(alpha: 0.25);
      textColor = const Color(0xFF4ade80);
    } else if (isPast) {
      backgroundColor = const Color(0xFF374151).withValues(alpha: 0.6);
      textColor = const Color(0xFF9ca3af);
    } else {
      backgroundColor = const Color(0xFF3498db).withValues(alpha: 0.25);
      textColor = const Color(0xFF60a5fa);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TVFocusableWidget(
        key: key,
        scale: 1.05,
        borderWidth: 2.0,
        borderColor: isLive ? const Color(0xFF27ae60) : Colors.white,
        onMenu: () {
          setState(() {
            _showTVChannelPanel = false;
          });
        },
        child: Container(
          width: 110,
          height: 72,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isLive ? const Color(0xFF27ae60) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                program.timeRange,
                style: FontUtils.poppins(
                  fontSize: 9,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                program.title,
                style: FontUtils.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// tvOS：频道列表（TVFocusableWidget 纵向导航，上下方向键切换频道）
  Widget _buildTVChannelList(ThemeService themeService) {
    final filteredChannels = _getFilteredChannels();

    if (filteredChannels.isEmpty) {
      return Center(
        child: Text(
          '暂无频道',
          style: FontUtils.poppins(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
      );
    }

    return TVFocusGrid(
      child: ListView.builder(
        controller: _channelScrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filteredChannels.length,
        itemBuilder: (context, index) {
          final channel = filteredChannels[index];
          final bool isCurrent = channel.id == _currentChannel.id;
          return _buildTVChannelItem(
            channel,
            themeService,
            isCurrent: isCurrent,
            // 当前频道绑定 GlobalKey，用于滚动定位 + FocusNode 聚焦
            key: isCurrent
                ? _currentChannelKey
                : ValueKey('tv_channel_${channel.id}'),
          );
        },
      ),
    );
  }

  /// tvOS：频道列表项。当前频道绿色高亮，Focus 时白色边框 + 缩放
  Widget _buildTVChannelItem(
    LiveChannel channel,
    ThemeService themeService, {
    required bool isCurrent,
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TVFocusableWidget(
        key: key,
        focusNode: isCurrent ? _tvCurrentChannelFocusNode : null,
        scale: 1.04,
        borderWidth: 2.0,
        borderColor: isCurrent ? const Color(0xFF27ae60) : Colors.white,
        onTap: () => _switchChannel(channel),
        onMenu: () {
          setState(() {
            _showTVChannelPanel = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFF27ae60).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 台标
              SizedBox(
                width: 48,
                height: 24,
                child: channel.logo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          channel.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildTVChannelLogoFallback(themeService),
                        ),
                      )
                    : _buildTVChannelLogoFallback(themeService),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  channel.name,
                  style: FontUtils.poppins(
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent ? const Color(0xFF27ae60) : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrent)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.play_arrow,
                    size: 20,
                    color: Color(0xFF27ae60),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTVChannelLogoFallback(ThemeService themeService) {
    return Container(
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? const Color(0xFF2a2a2a)
            : const Color(0xFFc0c0c0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.tv,
        size: 16,
        color: Color(0xFF95a5b0),
      ),
    );
  }

  /// 获取筛选后的频道列表
  List<LiveChannel> _getFilteredChannels() {
    if (_selectedGroup == '全部') {
      return _allChannels;
    } else {
      return _allChannels.where((c) => c.group == _selectedGroup).toList();
    }
  }

  /// 构建切换加载蒙版（只覆盖播放器）
  Widget _buildSwitchLoadingOverlay() {
    return SwitchLoadingOverlay(
      isVisible: _isLoading,
      message: _loadingMessage,
      animationController: _loadingAnimationController,
      onBackPressed: () => Navigator.pop(context),
    );
  }
}
