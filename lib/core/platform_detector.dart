import 'package:flutter/foundation.dart';

class PlatformDetector {
  static bool _isTVOS = false;

  static void init() {
    _isTVOS = const bool.fromEnvironment('TVOS', defaultValue: false);
  }

  static bool get isTVOS => _isTVOS;
  static bool get isIOS => !_isTVOS && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
  static bool get isPC => isWindows || isMacOS;
}
