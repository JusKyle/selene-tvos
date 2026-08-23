import 'dart:async';

abstract class PlayerAdapter {
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double speed);
  Future<void> setVolume(double volume);
  Future<void> open(String url, {Map<String, String>? headers, Duration? start});
  Future<void> dispose();
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<Duration> get durationStream;
  Duration? get position;
  Duration? get duration;
  bool get isPlaying;
}
