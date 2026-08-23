import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'tv_player_controls.dart';

/// tvOS 专用播放器组件，基于 [VideoPlayerController]（AVFoundation）。
/// 通过 [VideoPlayerWidgetController] 对外暴露播放控制接口。
class VideoPlayerWidget extends StatefulWidget {
  final String? url;
  final Map<String, String>? headers;
  final VoidCallback? onBackPressed;
  final Function(VideoPlayerWidgetController)? onControllerCreated;
  final VoidCallback? onReady;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onVideoCompleted;
  final VoidCallback? onPause;
  final bool isLastEpisode;
  final String? videoTitle;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final String? sourceName;
  final bool live;

  const VideoPlayerWidget({
    super.key,
    this.url,
    this.headers,
    this.onBackPressed,
    this.onControllerCreated,
    this.onReady,
    this.onNextEpisode,
    this.onVideoCompleted,
    this.onPause,
    this.isLastEpisode = false,
    this.videoTitle,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.sourceName,
    this.live = false,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class VideoPlayerWidgetController {
  VideoPlayerWidgetController._(this._state);
  final _VideoPlayerWidgetState _state;

  Future<void> updateDataSource(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    await _state._updateDataSource(
      url,
      startAt: startAt,
      headers: headers,
    );
  }

  Future<void> seekTo(Duration position) async {
    await _state._seek(position);
  }

  Duration? get currentPosition => _state._controller?.value.position;

  Duration? get duration => _state._controller?.value.duration;

  bool get isPlaying => _state._controller?.value.isPlaying ?? false;

  Future<void> pause() async {
    await _state._controller?.pause();
  }

  Future<void> play() async {
    await _state._controller?.play();
  }

  void addProgressListener(VoidCallback listener) {
    _state._addProgressListener(listener);
  }

  void removeProgressListener(VoidCallback listener) {
    _state._removeProgressListener(listener);
  }

  Future<void> setSpeed(double speed) async {
    await _state._setPlaybackSpeed(speed);
  }

  double get playbackSpeed => _state._playbackSpeed.value;

  Future<void> setVolume(double volume) async {
    await _state._controller?.setVolume(volume);
  }

  double? get volume => _state._controller?.value.volume;

  Future<void> dispose() async {
    await _state._externalDispose();
  }
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _hasCompleted = false;
  bool _isLoadingVideo = false;
  bool _readyFired = false;
  String? _currentUrl;
  Map<String, String>? _currentHeaders;
  final List<VoidCallback> _progressListeners = [];
  final ValueNotifier<double> _playbackSpeed = ValueNotifier<double>(1.0);
  bool _controllerDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _currentHeaders = widget.headers;
    _initializeController();
    widget.onControllerCreated?.call(VideoPlayerWidgetController._(this));
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.headers != oldWidget.headers && widget.headers != null) {
      _currentHeaders = widget.headers;
    }
    if (widget.url != oldWidget.url && widget.url != null) {
      unawaited(_updateDataSource(widget.url!));
    }
  }

  Future<void> _initializeController() async {
    if (_controllerDisposed || _currentUrl == null) {
      return;
    }
    setState(() {
      _isLoadingVideo = true;
    });
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_currentUrl!),
        httpHeaders: _currentHeaders ?? const <String, String>{},
      );
      _controller = controller;
      controller.addListener(_onControllerUpdate);
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed.value);
      await controller.play();
      if (!mounted || _controllerDisposed) return;
      setState(() {
        _isLoadingVideo = false;
      });
      if (!_readyFired) {
        _readyFired = true;
        widget.onReady?.call();
      }
    } catch (error) {
      debugPrint('VideoPlayerWidget: failed to open media $error');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final value = _controller!.value;

    for (final listener in List<VoidCallback>.from(_progressListeners)) {
      try {
        listener();
      } catch (error) {
        debugPrint('VideoPlayerWidget: progress listener error $error');
      }
    }

    if (value.isInitialized && _isLoadingVideo) {
      setState(() {
        _isLoadingVideo = false;
      });
    }

    if (value.isInitialized && !_readyFired) {
      _readyFired = true;
      widget.onReady?.call();
    }

    if (!widget.live && value.isCompleted && !_hasCompleted) {
      _hasCompleted = true;
      widget.onVideoCompleted?.call();
    }
  }

  Future<void> _updateDataSource(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    if (_controllerDisposed) {
      return;
    }
    _currentUrl = url;
    if (headers != null) {
      _currentHeaders = headers;
    }

    if (_controller == null) {
      await _initializeController();
      return;
    }

    setState(() {
      _isLoadingVideo = true;
    });

    final currentSpeed = _playbackSpeed.value;
    final oldController = _controller;
    _controller = null;
    oldController?.removeListener(_onControllerUpdate);
    await oldController?.dispose();

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _currentHeaders ?? const <String, String>{},
      );
      _controller = controller;
      controller.addListener(_onControllerUpdate);
      await controller.initialize();
      await controller.setPlaybackSpeed(currentSpeed);
      if (startAt != null) {
        await controller.seekTo(startAt);
      }
      await controller.play();
      if (mounted) {
        setState(() {
          _hasCompleted = false;
          _isLoadingVideo = false;
        });
      }
      _readyFired = true;
      widget.onReady?.call();
    } catch (error) {
      debugPrint('VideoPlayerWidget: error while changing source $error');
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  Future<void> _seek(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await controller.seekTo(position);
  }

  void _addProgressListener(VoidCallback listener) {
    if (!_progressListeners.contains(listener)) {
      _progressListeners.add(listener);
    }
  }

  void _removeProgressListener(VoidCallback listener) {
    _progressListeners.remove(listener);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed.value = speed;
    await _controller?.setPlaybackSpeed(speed);
  }

  void _playOrPause() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
      widget.onPause?.call();
    } else {
      controller.play();
    }
  }

  Future<void> _externalDispose() async {
    if (!mounted || _controllerDisposed) {
      return;
    }
    await _disposeController();
  }

  Future<void> _disposeController() async {
    if (_controllerDisposed) {
      return;
    }
    _controllerDisposed = true;
    _controller?.removeListener(_onControllerUpdate);
    await _controller?.dispose();
    _controller = null;
    _progressListeners.clear();
  }

  @override
  void dispose() {
    _disposeController();
    _playbackSpeed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      color: Colors.black,
      child: controller != null && controller.value.isInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                TVPlayerControls(
                  onPlayPause: _playOrPause,
                  onSeekForward: () async {
                    final pos = controller.value.position;
                    final next = pos + const Duration(seconds: 10);
                    if (next <= controller.value.duration) {
                      await controller.seekTo(next);
                    }
                  },
                  onSeekBackward: () async {
                    final pos = controller.value.position;
                    final next =
                        pos - const Duration(seconds: 10) < Duration.zero
                            ? Duration.zero
                            : pos - const Duration(seconds: 10);
                    await controller.seekTo(next);
                  },
                  onNextEpisode: widget.onNextEpisode,
                  onBack: widget.onBackPressed,
                  isPlaying: controller.value.isPlaying,
                  position: controller.value.position,
                  duration: controller.value.duration,
                  playbackSpeed: _playbackSpeed.value,
                  playbackSpeedListenable: _playbackSpeed,
                  onSetSpeed: _setPlaybackSpeed,
                  isLastEpisode: widget.isLastEpisode,
                  isLoading: _isLoadingVideo,
                  videoTitle: widget.videoTitle,
                  sourceName: widget.sourceName,
                  currentEpisodeIndex: widget.currentEpisodeIndex,
                  totalEpisodes: widget.totalEpisodes,
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
    );
  }
}
