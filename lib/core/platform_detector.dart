import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform detection utility.
///
/// Provides environment-aware booleans for tvOS, macOS, Windows, Linux,
/// desktop, and mobile platforms.
///
/// Call [init] at app startup (typically in main) to populate [_isTVOS].
class PlatformDetector {
  static bool _isTVOS = false;
  static bool _isIOS = false;
  static bool _isAndroid = false;
  static bool _isLinux = false;

  static void init() {
    _isTVOS = const String.fromEnvironment('TVOS').isNotEmpty;
    _isIOS = const String.fromEnvironment('IOS').isNotEmpty;
    _isAndroid = const String.fromEnvironment('ANDROID').isNotEmpty;
    _isLinux = const String.fromEnvironment('LINUX').isNotEmpty;

    if (!Platform.isIOS && !Platform.isAndroid) {
      if (!Platform.isMacOS && !Platform.isWindows) {
        if (!kIsWeb && !Platform.isMacOS && !Platform.isWindows) {
          // Fallback: attempt to detect tvOS via Platform.isIOS heuristic on CI.
          // The definitive source of truth is the TVOS environment flag above.
        }
      }
    }
  }

  static bool get isTVOS => _isTVOS;

  static bool get isIOS =>
      _isIOS || (!kIsWeb && Platform.isIOS && !_isTVOS);

  static bool get isAndroid => _isAndroid || (!kIsWeb && Platform.isAndroid);

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static bool get isLinux => _isLinux || (!kIsWeb && Platform.isLinux);

  static bool get isDesktop => isMacOS || isWindows || isLinux;

  static bool get isMobile =>
      (isIOS || isAndroid) && !isTVOS;

  static bool get isWeb => kIsWeb;
}
