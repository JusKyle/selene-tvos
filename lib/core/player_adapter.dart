import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// Unified player abstraction for cross-platform playback.
///
/// Desktop platforms use [media_kit] directly. tvOS can be adapted to
/// [video_player] in the future by providing a separate implementation.
abstract class PlayerAdapter {
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double speed);
  Future<void> setVolume(double volume);
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    Duration? start,
  });
  Future<void> dispose();

  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<Duration> get durationStream;

  Duration? get position;
  Duration? get duration;
  bool get isPlaying;
}

/// Default [PlayerAdapter] backed by [media_kit] [Player].
class MediaKitPlayerAdapter extends PlayerAdapter {
  final Player _player;

  MediaKitPlayerAdapter(this._player);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double speed) => _player.setRate(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    Duration? start,
  }) async {
    await _player.open(
      Media(
        url,
        start: start,
        httpHeaders: headers ?? const <String, String>{},
      ),
      play: true,
    );
  }

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Duration? get position => _player.state.position;

  @override
  Duration? get duration => _player.state.duration;

  @override
  bool get isPlaying => _player.state.playing ?? false;
}
