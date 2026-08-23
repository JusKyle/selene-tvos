import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tv_focusable.dart';

/// Apple TV (tvOS) dedicated player controls.
///
/// Replaces [PCPlayerControls] and [MobilePlayerControls] on tvOS.
/// Large high-contrast icons, thick progress bar, full-screen focus
/// panels for speed / episode / source selection.
class TVPlayerControls extends StatefulWidget {
  final VoidCallback? onPlayPause;
  final VoidCallback? onSeekForward;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onBack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final ValueNotifier<double>? playbackSpeedListenable;
  final Future<void> Function(double)? onSetSpeed;
  final bool isLastEpisode;
  final bool isLoading;
  final String? videoTitle;
  final String? sourceName;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final Widget? episodesPanel;
  final Widget? sourcesPanel;
  final VoidCallback? onEpisodesPressed;
  final VoidCallback? onSourcesPressed;
  final VoidCallback? onSpeedPressed;
  final VoidCallback? onDetailsPressed;
  final VoidCallback? onPiPPressed;
  final bool isPipMode;

  const TVPlayerControls({
    super.key,
    this.onPlayPause,
    this.onSeekForward,
    this.onSeekBackward,
    this.onNextEpisode,
    this.onBack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackSpeed = 1.0,
    this.playbackSpeedListenable,
    this.onSetSpeed,
    this.isLastEpisode = false,
    this.isLoading = false,
    this.videoTitle,
    this.sourceName,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.episodesPanel,
    this.sourcesPanel,
    this.onEpisodesPressed,
    this.onSourcesPressed,
    this.onSpeedPressed,
    this.onDetailsPressed,
    this.onPiPPressed,
    this.isPipMode = false,
  });

  @override
  State<TVPlayerControls> createState() => _TVPlayerControlsState();
}

class _TVPlayerControlsState extends State<TVPlayerControls>
    with SingleTickerProviderStateMixin {
  // 控制栏可见性
  bool _controlsVisible = true;
  Timer? _hideTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // 倍速选择面板
  bool _showSpeedPanel = false;
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0, 4.0];
  int _focusedSpeedIndex = 3;

  // 当前显示时间字符串
  String _currentTime = '0:00';
  String _totalTime = '0:00';

  // 进度条焦点
  FocusNode _progressFocusNode = FocusNode();
  FocusNode _rootFocusNode = FocusNode();
  late FocusScopeNode _rootFocusScope;

  @override
  void initState() {
    super.initState();
    _rootFocusScope = FocusScopeNode();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rootFocusScope.requestFocus();
        _updateTimeText();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fadeController.dispose();
    _progressFocusNode.dispose();
    _rootFocusNode.dispose();
    _rootFocusScope.dispose();
    super.dispose();
  }

  // ---- 时间格式化 ----

  String _formatDuration(Duration d) {
    if (d.inMilliseconds < 0) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final pad = (int v) => v.toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:${pad(m)}:${pad(s)}';
    }
    return '$m:${pad(s)}';
  }

  void _updateTimeText() {
    setState(() {
      _currentTime = _formatDuration(widget.position);
      _totalTime = _formatDuration(widget.duration);
    });
  }

  // ---- 控制栏显隐 ----

  void _showControls() {
    _fadeController.reverse(from: 0.0);
    setState(() => _controlsVisible = true);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.isPlaying && !widget.isLoading && !_showSpeedPanel) {
      _hideTimer = Timer(const Duration(seconds: 5), _hideControls);
    }
  }

  void _hideControls() {
    _fadeController.forward();
    setState(() => _controlsVisible = false);
  }

  // ---- 时间跳转展示 ----

  Duration? _seekOverlayPosition;
  Timer? _seekOverlayTimer;

  void _showSeekOverlay(Duration position) {
    setState(() => _seekOverlayPosition = position);
    _seekOverlayTimer?.cancel();
    _seekOverlayTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _seekOverlayPosition = null);
      }
    });
  }

  // ---- 键盘事件 ----

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    _showControls();

    // 速度面板打开时处理
    if (_showSpeedPanel) {
      return _handleSpeedPanelKeyEvent(event);
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        widget.onPlayPause?.call();
        _startHideTimer();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        _seekBackward();
        _startHideTimer();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        _seekForward();
        _startHideTimer();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        // 音量控制已禁用，由系统处理
        return KeyEventResult.ignored;

      case LogicalKeyboardKey.escape:
        widget.onBack?.call();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleSpeedPanelKeyEvent(KeyDownEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowUp:
        if (_focusedSpeedIndex > 0) {
          setState(() => _focusedSpeedIndex--);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowDown:
        if (_focusedSpeedIndex < _speedOptions.length - 1) {
          setState(() => _focusedSpeedIndex++);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _selectSpeed(_speedOptions[_focusedSpeedIndex]);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.escape:
        setState(() => _showSpeedPanel = false);
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  // ---- 播放控制 ----

  void _seekForward() {
    if (widget.duration.inMilliseconds <= 0) return;
    final next = widget.position + const Duration(seconds: 10);
    if (next <= widget.duration) {
      widget.onSeekForward?.call();
      _showSeekOverlay(next);
    }
  }

  void _seekBackward() {
    final next = widget.position - const Duration(seconds: 10);
    if (next >= Duration.zero) {
      widget.onSeekBackward?.call();
      _showSeekOverlay(next);
    } else {
      widget.onSeekBackward?.call();
      _showSeekOverlay(Duration.zero);
    }
  }

  void _selectSpeed(double speed) async {
    widget.onSetSpeed?.call(speed);
    setState(() => _showSpeedPanel = false);
    _startHideTimer();
  }

  // ---- UI ----

  // 倍速选择全屏面板
  Widget _buildSpeedPanel() {
    final itemCount = _speedOptions.length;
    const cols = 4;
    final rows = (itemCount / cols).ceil();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Focus(
          focusNode: _rootFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) => _handleSpeedPanelKeyEvent(
              event is KeyDownEvent ? event : KeyDownEvent(
                event.key,
                repeat: event is KeyDownEvent ? false : true,
              )),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '播放速度',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 24,
                    childAspectRatio: 3,
                  ),
                  itemCount: rows * cols,
                  itemBuilder: (context, idx) {
                    if (idx >= itemCount) return const SizedBox.shrink();
                    final speed = _speedOptions[idx];
                    final focused = idx == _focusedSpeedIndex;
                    final selected =
                        speed == widget.playbackSpeed;
                    return TVFocusableWidget(
                      focusNode: focused
                          ? null
                          : null,
                      onTap: () => _selectSpeed(speed),
                      borderColor: Colors.green,
                      scale: focused ? 1.1 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.green
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${speed}x',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white,
                            fontSize: 28,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Menu 返回',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 操作行按钮
  Widget _controlButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? label,
  }) {
    final enabled = onTap != null;
    return TVFocusableWidget(
      onTap: onTap,
      borderColor: Colors.green,
      scale: 1.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.white38,
              size: 48,
            ),
            if (label != null)
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white30,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 更新时长
    if (_totalTime != _formatDuration(widget.duration)) {
      _updateTimeText();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 控制栏高度
        final barHeight = 140.0;

        return Stack(
          children: [
            // 全屏按键焦点范围
            Positioned.fill(
              child: Focus(
                focusNode: _rootFocusScope,
                autofocus: true,
                onKeyEvent: (node, event) => _handleKeyEvent(event),
                child: GestureDetector(
                  onTap: () {
                    _showControls();
                    _startHideTimer();
                  },
                ),
              ),
            ),

            // 倍速面板
            if (_showSpeedPanel) _buildSpeedPanel(),

            // 剧集/源面板
            if (_showSpeedPanel == false && widget.episodesPanel != null)
              widget.episodesPanel!,
            if (_showSpeedPanel == false && widget.sourcesPanel != null)
              widget.sourcesPanel!,

            // 跳转提示
            if (_seekOverlayPosition != null)
              _buildSeekOverlay(_seekOverlayPosition!, constraints.maxWidth),

            // 顶部标题条（淡入淡出）
            AnimatedOpacity(
              opacity: _controlsVisible ? _fadeAnimation.value : 0.0,
              duration: const Duration(milliseconds: 400),
              child: _buildTopBar(constraints.maxWidth),
            ),

            // 底部控制栏（淡入淡出）
            AnimatedOpacity(
              opacity: _controlsVisible ? _fadeAnimation.value : 0.0,
              duration: const Duration(milliseconds: 400),
              child: _buildBottomControls(constraints.maxWidth, barHeight),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeekOverlay(Duration pos, double screenWidth) {
    return Positioned(
      top: screenWidth / 2 - 60,
      left: screenWidth / 2 - 200,
      width: 400,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        alignment: Alignment.center,
        child: Text(
          _formatDuration(pos),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(double width) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Row(
          children: [
            Text(
              widget.videoTitle ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (widget.sourceName != null)
              Text(
                widget.sourceName!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(double width, double barHeight) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: barHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 进度条
            _buildProgressBar(),
            const SizedBox(height: 8),
            // 时间行 + 操作按钮行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  // 时间
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _totalTime,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const Spacer(),

                  // 上一集（可选）
                  if (!widget.isLastEpisode) ...[
                    _controlButton(
                      icon: Icons.skip_previous,
                      onTap: widget.onNextEpisode,
                    ),
                  ],

                  // 快退
                  _controlButton(
                    icon: Icons.replay_10,
                    onTap: widget.onSeekBackward,
                  ),

                  // 播放/暂停（中心大按钮）
                  TVFocusableWidget(
                    onTap: widget.onPlayPause,
                    borderColor: Colors.green,
                    scale: 1.15,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),

                  // 快进
                  _controlButton(
                    icon: Icons.forward_10,
                    onTap: widget.onSeekForward,
                  ),

                  // 下一集
                  if (!widget.isLastEpisode) ...[
                    _controlButton(
                      icon: Icons.skip_next,
                      onTap: widget.onNextEpisode,
                    ),
                  ],

                  const SizedBox(width: 8),

                  // 剧集面板
                  _controlButton(
                    icon: Icons.list,
                    onTap: widget.onEpisodesPressed,
                    label: '选集',
                  ),

                  // 源面板
                  _controlButton(
                    icon: Icons.swap_horiz,
                    onTap: widget.onSourcesPressed,
                    label: '换源',
                  ),

                  // 倍速
                  _controlButton(
                    icon: Icons.speed,
                    onTap: () {
                      setState(() => _showSpeedPanel = true);
                    },
                    label: '${widget.playbackSpeed}x',
                  ),

                  // PiP
                  if (widget.onPiPPressed != null)
                    _controlButton(
                      icon: widget.isPipMode
                          ? Icons.picture_in_picture
                          : Icons.picture_in_picture_alt,
                      onTap: widget.onPiPPressed,
                      label: widget.isPipMode ? 'PiP' : '',
                    ),

                  // 返回
                  _controlButton(
                    icon: Icons.arrow_back,
                    onTap: widget.onBack,
                    label: '返回',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: TVFocusableWidget(
        onTap: () {
          widget.onPlayPause?.call();
          _startHideTimer();
        },
        borderColor: Colors.green,
        scale: 1.02,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: CustomPaint(
            size: Size(double.infinity, 16),
            painter: _ProgressBarPainter(
              progress: widget.duration.inMilliseconds > 0
                  ? widget.position.inMilliseconds /
                      widget.duration.inMilliseconds
                  : 0.0,
              buffered: 0.0,
              trackColor: Colors.white.withValues(alpha: 0.3),
              progressColor: Colors.white,
              handleColor: Colors.green,
              trackHeight: 8,
              handleRadius: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// 粗进度条自绘
class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final double buffered;
  final Color trackColor;
  final Color progressColor;
  final Color handleColor;
  final double trackHeight;
  final double handleRadius;

  _ProgressBarPainter({
    required this.progress,
    required this.buffered,
    required this.trackColor,
    required this.progressColor,
    required this.handleColor,
    required this.trackHeight,
    required this.handleRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = Rect.fromCenter(
      center: Offset(size.width * progress, size.height / 2),
      width: size.width,
      height: trackHeight,
    );

    // 轨道
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.fill,
    );

    // 进度
    final progWidth = size.width * progress;
    if (progWidth > 0) {
      final progRect = Rect.fromLTWH(
        0,
        (size.height - trackHeight) / 2,
        progWidth,
        trackHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(progRect, const Radius.circular(4)),
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.fill,
      );
    }

    // 拖动手柄
    final handleX = size.width * progress;
    final handleY = size.height / 2;
    canvas.drawCircle(
      Offset(handleX, handleY),
      handleRadius,
      Paint()
        ..color = handleColor
        ..style = PaintingStyle.fill,
    );

    // 手柄描边
    canvas.drawCircle(
      Offset(handleX, handleY),
      handleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
