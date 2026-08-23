import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'player_adapter.dart';

class VideoPlayerAdapter extends PlayerAdapter {
  VideoPlayerController? _controller;
  final StreamController<Duration> _positionController = StreamController.broadcast();
  final StreamController<bool> _playingController = StreamController.broadcast();
  final StreamController<bool> _completedController = StreamController.broadcast();
  final StreamController<Duration> _durationController = StreamController.broadcast();
  StreamSubscription? _listener;

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> setRate(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _controller?.setVolume(volume);
  }

  @override
  Future<void> open(String url, {Map<String, String>? headers, Duration? start}) async {
    await _controller?.pause();
    await _controller?.dispose();

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers ?? {},
    );

    await _controller!.initialize();
    if (start != null) {
      await _controller!.seekTo(start);
    }

    _listener?.cancel();
    _listener = _controller!.addListener(() {
      final value = _controller!.value;
      _positionController.add(value.position);
      _playingController.add(value.isPlaying);
      _durationController.add(value.duration);
      if (value.isCompleted) {
        _completedController.add(true);
      }
    });

    _durationController.add(_controller!.value.duration);
    await _controller!.play();
  }

  @override
  Future<void> dispose() async {
    _listener?.cancel();
    await _controller?.dispose();
    await _positionController.close();
    await _playingController.close();
    await _completedController.close();
    await _durationController.close();
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Duration? get position => _controller?.value.position;

  @override
  Duration? get duration => _controller?.value.duration;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;
}
