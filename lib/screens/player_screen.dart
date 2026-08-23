import 'package:flutter/material.dart';
import '../core/platform_detector.dart';
import 'package:flutter/services.dart';
import '../widgets/video_player_widget.dart';
import '../services/api_service.dart';
import '../services/m3u8_service.dart';
import '../services/user_data_service.dart';
import '../services/search_service.dart';
import '../models/search_result.dart';
import '../models/play_record.dart';
import '../services/page_cache_service.dart';
import '../widgets/switch_loading_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final String? source;
  final String? id;
  final String title;
  final String? year;
  final String? stitle;
  final String? stype;
  final String? prefer;

  const PlayerScreen({
    super.key,
    this.source,
    this.id,
    required this.title,
    this.year,
    this.stitle,
    this.stype,
    this.prefer,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late SystemUiOverlayStyle _originalStyle;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showError = false;

  // 加载状态
  bool _isLoading = true;
  String _loadingMessage = '正在搜索播放源...';
  String _loadingEmoji = '🔍'; // 加载图标 emoji
  double _loadingProgress = 0.0; // 加载进度百分比 (0.0 - 1.0)
  late AnimationController _loadingAnimationController;
  late AnimationController _textAnimationController;

  // 播放信息
  SearchResult? currentDetail;
  String searchTitle = '';
  String videoTitle = '';
  String videoDesc = '';
  String videoYear = '';
  String videoCover = '';
  String currentSource = '';
  String currentID = '';
  bool needPrefer = false;
  int totalEpisodes = 0;
  int currentEpisodeIndex = 0;

  // 所有源信息
  List<SearchResult> allSources = [];
  // 所有源测速结果
  Map<String, SourceSpeed> allSourcesSpeed = {};

  // VideoPlayerWidget 的控制器
  VideoPlayerWidgetController? _videoPlayerController;

  // 切换播放源/集数时的加载蒙版状态
  bool _showSwitchLoadingOverlay = false;
  String _switchLoadingMessage = '切换播放源...';
  late AnimationController _switchLoadingAnimationController;

  // 保存进度相关状态
  DateTime? _lastSaveTime;
  int? _lastSavePosition; // 上次保存的播放位置（秒）
  static const Duration _saveProgressInterval = Duration(seconds: 10);
  Duration? _resumeStartAt;

  // 播放器的 GlobalKey，用于保持播放器状态
  final GlobalKey _playerKey = GlobalKey();
  int _loadGeneration = 0;

  bool _isActiveLoad(int generation) =>
      mounted && generation == _loadGeneration;

  @override
  void initState() {
    super.initState();
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _switchLoadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    // 添加应用生命周期监听器
    WidgetsBinding.instance.addObserver(this);
  }

  void initParam() {
    currentSource = widget.source ?? '';
    currentID = widget.id ?? '';
    videoTitle = widget.title;
    videoYear = widget.year ?? '';
    needPrefer = widget.prefer != null && widget.prefer == 'true';
    searchTitle = widget.stitle ?? '';

    debugPrint('=== PlayerScreen 初始化参数 ===');
    debugPrint('currentSource: $currentSource');
    debugPrint('currentID: $currentID');
    debugPrint('videoTitle: $videoTitle');
    debugPrint('videoYear: $videoYear');
    debugPrint('needPrefer: $needPrefer');
    debugPrint('stitle: ${widget.stitle}');
    debugPrint('stype: ${widget.stype}');
    debugPrint('prefer: ${widget.prefer}');
  }

  void initVideoData() async {
    final loadGeneration = ++_loadGeneration;

    if (widget.source == null &&
        widget.id == null &&
        widget.title.isEmpty &&
        widget.stitle == null) {
      showError('缺少必要参数');
      return;
    }

    // 读取优选测速配置
    final preferSpeedTest = await UserDataService.getPreferSpeedTest();
    if (!_isActiveLoad(loadGeneration)) return;

    if (!preferSpeedTest ||
        (widget.source != null &&
            widget.id != null &&
            (widget.prefer == null || widget.prefer != 'true'))) {
      updateLoadingMessage('正在获取播放源详情...');
      updateLoadingProgress(0.5);
      updateLoadingEmoji('🔍');
    } else {
      updateLoadingMessage('正在搜索播放源...');
      updateLoadingProgress(0.33);
      updateLoadingEmoji('🔍');
    }

    // 初始化参数
    initParam();

    // 执行查询
    allSources = await fetchSourcesData(
        (searchTitle.isNotEmpty) ? searchTitle : videoTitle);
    if (!_isActiveLoad(loadGeneration)) return;

    if (currentSource.isNotEmpty &&
        currentID.isNotEmpty &&
        !allSources.any((source) =>
            source.source == currentSource && source.id == currentID)) {
      allSources = await fetchSourceDetail(currentSource, currentID);
      if (!_isActiveLoad(loadGeneration)) return;
    }
    if (allSources.isEmpty) {
      showError('未找到匹配结果');
      return;
    }

    // 指定源和id且无需优选
    currentDetail = allSources.first;
    if (currentSource.isNotEmpty && currentID.isNotEmpty && !needPrefer) {
      final target = allSources.where(
          (source) => source.source == currentSource && source.id == currentID);
      currentDetail = target.isNotEmpty ? target.first : null;
    }
    if (currentDetail == null) {
      showError('未找到匹配结果');
      return;
    }

    // 未指定源和 id/需要优选，且优选测速开关打开时，执行优选
    if ((currentSource.isEmpty || currentID.isEmpty || needPrefer) &&
        preferSpeedTest) {
      updateLoadingMessage('正在优选最佳播放源...');
      updateLoadingProgress(0.66);
      updateLoadingEmoji('⚡');
      currentDetail = await preferBestSource();
      if (!_isActiveLoad(loadGeneration)) return;
    }
    setInfosByDetail(currentDetail!);

    // 获取播放记录
    int playEpisodeIndex = 0;
    int playTime = 0;
    if (mounted) {
      final allPlayRecords = await PageCacheService().getPlayRecords(context);
      if (!_isActiveLoad(loadGeneration)) return;
      // 查找是否有当前视频的播放记录
      if (allPlayRecords.success && allPlayRecords.data != null) {
        final matchingRecords = allPlayRecords.data!.where((record) =>
            record.id == currentID && record.source == currentSource);
        if (matchingRecords.isNotEmpty) {
          playEpisodeIndex = matchingRecords.first.index - 1;
          playTime = matchingRecords.first.playTime;
        }
      }
    }

    // 设置进度为 100%
    updateLoadingProgress(1.0);
    updateLoadingMessage('准备就绪，即将开始播放...');
    updateLoadingEmoji('✨');

    if (mounted) {
      setState(() {
        _showSwitchLoadingOverlay = true;
        _switchLoadingMessage = '视频加载中...';
      });
    }

    // 延时 1 秒后隐藏加载界面
    Future.delayed(const Duration(seconds: 1), () {
      if (_isActiveLoad(loadGeneration)) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // 设置播放
    if (!_isActiveLoad(loadGeneration)) return;
    startPlay(playEpisodeIndex, playTime);
  }

  void startPlay(int targetIndex, int playTime) {
    if (currentDetail!.episodes.isEmpty) return;
    if (targetIndex < 0 || targetIndex >= currentDetail!.episodes.length) {
      // 越界时回退到第 0 集继续播放，避免卡在加载界面
      targetIndex = 0;
    }
    if (mounted) {
      setState(() {
        currentEpisodeIndex = targetIndex;
      });
    }
    // 重置上次保存的位置，因为切换了集数
    _lastSavePosition = null;
    // 将 playTime 转换为 Duration 并传递给 updateVideoUrl
    final startAt = playTime > 0 ? Duration(seconds: playTime) : null;
    _resumeStartAt = startAt;
    updateVideoUrl(currentDetail!.episodes[targetIndex], startAt: null);
  }

  void setInfosByDetail(SearchResult detail) {
    videoTitle = detail.title;
    videoDesc = detail.desc ?? '';
    videoYear = detail.year;
    videoCover = detail.poster;
    currentSource = detail.source;
    currentID = detail.id;
    totalEpisodes = detail.episodes.length;
  }

  Future<SearchResult> preferBestSource() async {
    final m3u8Service = M3U8Service();
    final result = await m3u8Service.preferBestSource(allSources);

    // 更新测速结果
    final speedResults = result['allSourcesSpeed'] as Map<String, dynamic>;
    for (final entry in speedResults.entries) {
      final speedData = entry.value as Map<String, dynamic>;
      allSourcesSpeed[entry.key] = SourceSpeed(
        quality: speedData['quality'] as String,
        loadSpeed: speedData['loadSpeed'] as String,
        pingTime: speedData['pingTime'] as String,
      );
    }

    return result['bestSource'] as SearchResult;
  }

  // 处理返回按钮点击
  void _onBackPressed() async {
    // 关闭页面前保存进度
    if (!mounted) return;
    _saveProgress(force: true, scene: '返回按钮');
    Navigator.of(context).pop();
  }

  /// 保存播放进度（同步函数，提前获取参数避免异步问题）
  void _saveProgress({bool force = false, required String scene}) {
    try {
      if (currentDetail == null) return;

      // 获取当前播放位置和总时长
      Duration? currentPosition;
      Duration? duration;

      if (_videoPlayerController == null) return;
      currentPosition = _videoPlayerController!.currentPosition;
      duration = _videoPlayerController!.duration;

      if (currentPosition == null || duration == null) return;

      // 如果播放进度小于 1 s，则不保存
      if (currentPosition.inSeconds < 1) {
        return;
      }

      final playTime = currentPosition.inSeconds;
      final totalTime = duration.inSeconds;
      // 如果不是强制保存，检查时间间隔和进度变化
      if (!force) {
        final now = DateTime.now();
        // 检查时间间隔
        if (_lastSaveTime != null &&
            now.difference(_lastSaveTime!) < _saveProgressInterval) {
          return; // 时间间隔不够，跳过保存
        }
        // 检查进度是否发生变化（允许1秒的误差）
        if (_lastSavePosition != null && playTime == _lastSavePosition!) {
          return; // 进度没有明显变化，跳过保存
        }
      }

      // 更新最后保存时间和位置
      _lastSaveTime = DateTime.now();
      _lastSavePosition = playTime;

      // 提前获取所有需要的参数，避免异步执行时参数被改变
      final currentIDSnapshot = currentID;
      final currentSourceSnapshot = currentSource;
      final videoTitleSnapshot = videoTitle;
      final videoYearSnapshot = videoYear;
      final videoCoverSnapshot = videoCover;
      final currentEpisodeIndexSnapshot = currentEpisodeIndex;
      final totalEpisodesSnapshot = totalEpisodes;
      final searchTitleSnapshot = searchTitle;
      final sourceNameSnapshot = currentDetail?.sourceName ?? currentSource;

      // 创建播放记录对象
      final playRecord = PlayRecord(
        id: currentIDSnapshot,
        source: currentSourceSnapshot,
        title: videoTitleSnapshot,
        sourceName: sourceNameSnapshot,
        year: videoYearSnapshot,
        cover: videoCoverSnapshot,
        index: currentEpisodeIndexSnapshot + 1, // 转换为1开始的索引
        totalEpisodes: totalEpisodesSnapshot,
        playTime: playTime,
        totalTime: totalTime,
        saveTime: DateTime.now().millisecondsSinceEpoch, // 当前时间戳（毫秒）
        searchTitle: searchTitleSnapshot,
      );

      // 异步保存播放记录（不等待结果）
      PageCacheService().savePlayRecord(playRecord, context).then((_) {
        debugPrint(
            '保存播放进度 [场景: $scene]: source: $currentSourceSnapshot, id: $currentIDSnapshot, 第${currentEpisodeIndexSnapshot + 1}集, 时间: $playTime秒');
      }).catchError((e) {
        debugPrint('保存播放进度失败 [场景: $scene]: $e');
      });
    } catch (e) {
      debugPrint('保存播放进度失败: $e');
    }
  }

  /// 检查并保存进度（基于时间间隔）
  void _checkAndSaveProgress() {
    _saveProgress(scene: '定时保存');
  }

  /// 应用生命周期状态变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // 应用进入后台前保存进度
        _saveProgress(force: true, scene: '应用进入后台');
        break;
      case AppLifecycleState.resumed:
        _lastSaveTime = null;
        _lastSavePosition = null;
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// 显示错误信息
  void showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _showError = true;
        _isLoading = false;
      });
    }
  }

  /// 隐藏错误信息
  void hideError() {
    if (mounted) {
      setState(() {
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  void updateLoadingMessage(String message) {
    if (mounted) {
      setState(() {
        _loadingMessage = message;
      });
    }
  }

  /// 更新加载进度
  void updateLoadingProgress(double progress) {
    if (mounted) {
      setState(() {
        _loadingProgress = progress.clamp(0.0, 1.0);
      });
    }
  }

  /// 更新加载 emoji
  void updateLoadingEmoji(String emoji) {
    if (mounted) {
      setState(() {
        _loadingEmoji = emoji;
      });
    }
  }

  /// 动态更新视频数据源
  Future<void> updateVideoUrl(String newUrl, {Duration? startAt}) async {
    debugPrint("newUrl: $newUrl, startAt: $startAt");
    try {
      // 获取 M3U8 代理 URL
      final m3u8ProxyUrl = await UserDataService.getM3u8ProxyUrl();

      // 如果代理 URL 不为空，则将 newUrl encode 后拼接到代理 URL 后面
      String finalUrl = newUrl;
      if (m3u8ProxyUrl.isNotEmpty) {
        final encodedUrl = Uri.encodeComponent(newUrl);
        finalUrl = '$m3u8ProxyUrl$encodedUrl';
        debugPrint("使用 M3U8 代理: $finalUrl");
      }

      await _videoPlayerController?.updateDataSource(finalUrl,
          startAt: startAt);
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 跳转到指定进度
  Future<void> seekToProgress(Duration position) async {
    try {
      await _videoPlayerController?.seekTo(position);
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 跳转到指定秒数
  Future<void> seekToSeconds(double seconds) async {
    await seekToProgress(Duration(seconds: seconds.round()));
  }

  /// 获取当前播放位置
  Duration? get currentPosition {
    return _videoPlayerController?.currentPosition;
  }

  /// 处理视频播放器 ready 事件
  void _onVideoPlayerReady() {
    if (!mounted) return;

    // 视频播放器准备就绪时的处理逻辑
    debugPrint('Video player is ready!');

    setState(() {
      // 隐藏切换加载蒙版
      _showSwitchLoadingOverlay = false;
    });

    // 重置最后保存时间，允许立即保存
    _lastSaveTime = null;

    // 添加视频播放状态监听器来触发保存检查
    _addVideoProgressListener();

    // 延时三秒 seek 到 _resumeStartAt
    if (_resumeStartAt != null) {
      final tmpStartAt = _resumeStartAt;
      _resumeStartAt = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && tmpStartAt != null) {
          seekToProgress(tmpStartAt);
        }
      });
    }
  }

  /// 添加视频播放进度监听器
  void _addVideoProgressListener() {
    if (_videoPlayerController != null) {
      // 添加进度监听器
      _videoPlayerController!.addProgressListener(_onVideoProgressUpdate);
    }
  }

  /// 移除视频播放进度监听器
  void _removeVideoProgressListener() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.removeProgressListener(_onVideoProgressUpdate);
    }
  }

  /// 视频播放进度更新回调
  void _onVideoProgressUpdate() {
    // 检查并保存进度（基于时间间隔）
    _checkAndSaveProgress();
  }

  /// 处理下一集按钮点击
  void _onNextEpisode() {
    if (currentDetail == null) return;

    // 检查是否为最后一集
    if (currentEpisodeIndex >= currentDetail!.episodes.length - 1) {
      _showToast('已经是最后一集了');
      return;
    }

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换选集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '下一集按钮');

    // 播放下一集
    final nextIndex = currentEpisodeIndex + 1;
    startPlay(nextIndex, 0);
  }

  /// 处理视频播放完成
  void _onVideoCompleted() {
    if (currentDetail == null) return;

    // 检查是否为最后一集
    if (currentEpisodeIndex >= currentDetail!.episodes.length - 1) {
      _showToast('播放完成');
      return;
    }

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '自动播放下一集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '自动播放下一集');

    // 自动播放下一集
    final nextIndex = currentEpisodeIndex + 1;
    startPlay(nextIndex, 0);
  }

  /// 显示Toast消息
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }


  /// 构建播放器组件
  Widget _buildPlayerWidget() {
    return Stack(
      children: [
        VideoPlayerWidget(
          url: null,
          onBackPressed: _onBackPressed,
          onControllerCreated: (controller) {
            _videoPlayerController = controller;
          },
          onReady: _onVideoPlayerReady,
          onNextEpisode: _onNextEpisode,
          onVideoCompleted: _onVideoCompleted,
          onPause: () {
            // 暂停时保存进度
            _saveProgress(force: true, scene: '暂停');
          },
          isLastEpisode: currentDetail != null &&
              currentEpisodeIndex >= currentDetail!.episodes.length - 1,
          videoTitle: videoTitle,
          currentEpisodeIndex: currentEpisodeIndex,
          totalEpisodes: totalEpisodes,
          sourceName: currentDetail?.sourceName ?? currentSource,
        ),
        // 切换播放源/集数时的加载蒙版（只遮挡播放器）
        SwitchLoadingOverlay(
          isVisible: _showSwitchLoadingOverlay,
          message: _switchLoadingMessage,
          animationController: _switchLoadingAnimationController,
          onBackPressed: _onBackPressed,
        ),
      ],
    );
  }

  /// 构建错误覆盖层
  Widget _buildErrorOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
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
        color: isDarkMode ? Colors.black : null,
      ),
      child: Stack(
        children: [
          // 装饰性圆点
          Positioned(
            top: 100,
            left: 40,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: 60,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 50,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 主要内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 错误图标
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8C42), Color(0xFFE74C3C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '😵',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 错误标题
                Text(
                  '哎呀, 出现了一些问题',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 错误信息框
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B4513).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // 提示文字
                Text(
                  '请检查网络连接或尝试刷新页面',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 按钮组
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // 返回按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            hideError();
                            _onBackPressed();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            '返回上页',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 重试按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: hideError,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFE2E8F0),
                            foregroundColor: isDarkMode
                                ? Colors.white
                                : const Color(0xFF3182CE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            '重新尝试',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF3182CE),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取视频详情
  Future<List<SearchResult>> fetchSourceDetail(String source, String id) async {
    // 检查是否启用本地搜索
    final isLocalSearch = await UserDataService.getLocalSearch();
    if (isLocalSearch) {
      return await SearchService.getDetailSync(source, id);
    } else {
      return await ApiService.fetchSourceDetail(source, id);
    }
  }

  /// 搜索视频源数据（带过滤）
  Future<List<SearchResult>> fetchSourcesData(String query) async {
    // 检查是否启用本地搜索
    final isLocalSearch = await UserDataService.getLocalSearch();
    final isLocalMode = await UserDataService.getIsLocalMode();

    List<SearchResult> results;
    if (isLocalSearch || isLocalMode) {
      // 使用本地搜索
      results = await SearchService.searchSync(query);
    } else {
      // 使用服务器搜索
      results = await ApiService.fetchSourcesData(query);
    }

    // 直接在这里展开过滤逻辑
    return results.where((result) {
      // 标题匹配检查
      final titleMatch = result.title.replaceAll(' ', '').toLowerCase() ==
          (widget.title.replaceAll(' ', '').toLowerCase());

      // 年份匹配检查
      final yearMatch = widget.year == null ||
          result.year.toLowerCase() == widget.year!.toLowerCase();

      // 类型匹配检查
      bool typeMatch = true;
      if (widget.stype != null) {
        if (widget.stype == 'tv') {
          typeMatch = result.episodes.length > 1;
        } else if (widget.stype == 'movie') {
          typeMatch = result.episodes.length == 1;
        }
      }

      return titleMatch && yearMatch && typeMatch;
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // 确保平台检测就绪
      PlatformDetector.init();

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

      // 初始化视频数据
      initVideoData();
    }
  }

  @override
  void dispose() {
    // 保存进度
    _saveProgress(force: true, scene: '页面销毁');
    // 移除视频进度监听器
    _removeVideoProgressListener();
    // 移除应用生命周期监听器
    WidgetsBinding.instance.removeObserver(this);
    // 恢复原始的系统UI样式
    SystemChrome.setSystemUIOverlayStyle(_originalStyle);
    // 销毁播放器
    _videoPlayerController?.dispose();
    // 释放动画控制器
    _loadingAnimationController.dispose();
    _textAnimationController.dispose();
    _switchLoadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
          child: Stack(
            children: [
              // tvOS 全屏播放器层
              _buildTVPlayerLayer(theme),
              // 错误覆盖层
              if (_showError && _errorMessage != null)
                _buildErrorOverlay(theme),
              // 加载覆盖层
              if (_isLoading) _buildLoadingOverlay(theme),
            ],
          ),
        ),
      ),
    );
  }


  /// tvOS 全屏播放器层。
  ///
  /// 占据整个屏幕，直接返回 [VideoPlayerWidget]（无外框装饰）。
  Widget _buildTVPlayerLayer(ThemeData theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: _playerKey,
        color: Colors.black,
        child: _buildPlayerWidget(),
      ),
    );
  }

  /// 构建加载覆盖层
  Widget _buildLoadingOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
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
        color: isDarkMode ? Colors.black : null,
      ),
      child: Stack(
        children: [
          // 中心加载内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 旋转的背景方块（半透明绿色）
                    RotationTransition(
                      turns: _loadingAnimationController,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ecc71).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // 中间的图标容器（减小尺寸，删除阴影）
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _loadingEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // 进度条
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loadingProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ecc71),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 加载文案
                AnimatedBuilder(
                  animation: _textAnimationController,
                  builder: (context, child) {
                    return Text(
                      _loadingMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: (isDarkMode ? Colors.white70 : Colors.black54)
                            .withValues(alpha: 
                          0.3 + (_textAnimationController.value * 0.7),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

