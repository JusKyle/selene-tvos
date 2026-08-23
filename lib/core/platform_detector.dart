import 'package:flutter/foundation.dart';

class PlatformDetector {
  static bool _isTVOS = false;

  static void init() {
    _isTVOS = bool.fromEnvironment('TVOS', defaultValue: false);
  }

  static bool get isTVOS => _isTVOS;
  static bool get isIOS => !_isTVOS && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
  static bool get isDesktop => isMacOS || isWindows || isLinux;
  static bool get isMobile => (isIOS || isAndroid) && !isTVOS;
}
