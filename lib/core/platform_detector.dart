class PlatformDetector {
  static bool _isTVOS = false;

  static void init() {
    _isTVOS = const bool.fromEnvironment('TVOS', defaultValue: false);
  }

  static bool get isTVOS => _isTVOS;
}
