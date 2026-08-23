import 'dart:io';

import 'package:flutter/foundation.dart';

/// 平台检测工具类
/// 提供跨平台判断能力，支持 tvOS 平台检测
/// 注：此文件由 Phase 1 团队维护，Phase 2 引用此接口
class PlatformDetector {
  static bool _isTVOS = false;
  static bool _isIOS = false;
  static bool _isAndroid = false;
  static bool _isLinux = false;

  /// 初始化平台检测（应在应用启动时调用）
  static void init() {
    _isTVOS = false;
    _isIOS = Platform.isIOS;
    _isAndroid = Platform.isAndroid;
    _isLinux = Platform.isLinux;
  }

  /// 是否为 tvOS 平台
  static bool get isTVOS => _isTVOS;

  /// 是否为 macOS 平台
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  /// 是否为 Windows 平台
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

  /// 是否为 Linux 平台
  static bool get isLinux => _isLinux || defaultTargetPlatform == TargetPlatform.linux;

  /// 是否为 iOS 平台
  static bool get isIOS => _isIOS && !isTVOS;

  /// 是否为 Android 平台
  static bool get isAndroid => _isAndroid;

  /// 是否为桌面端（macOS / Windows / Linux）
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// 是否为移动端（iOS / Android，排除 tvOS）
  static bool get isMobile => (isIOS || isAndroid) && !isTVOS;

  /// 是否为 PC（Windows / macOS）
  static bool get isPC => isWindows || isMacOS;
}
