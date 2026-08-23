import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../utils/image_url.dart';
import '../utils/font_utils.dart';
import '../services/theme_service.dart';

/// 全屏图片查看器
class FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String source;
  final String title;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.source,
    required this.title,
  });

  /// 显示全屏图片查看器
  static void show(
    BuildContext context, {
    required String imageUrl,
    required String source,
    required String title,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => FullscreenImageViewer(
          imageUrl: imageUrl,
          source: source,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final isDark = themeService.isDarkMode;
        final backgroundColor = isDark ? Colors.black : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF2c3e50);
        final progressIndicatorColor = isDark ? Colors.white : const Color(0xFF2c3e50);
        
        return Scaffold(
          backgroundColor: backgroundColor,
          body: Stack(
            children: [
              // 背景点击区域
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(), // 点击背景区域关闭
                  child: Container(color: Colors.transparent),
                ),
              ),
              
              // 图片区域
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(), // 点击图片也关闭
                  child: FutureBuilder<String>(
                    future: getImageUrl(widget.imageUrl, widget.source),
                    builder: (context, snapshot) {
                      final String imageUrl = snapshot.data ?? widget.imageUrl;
                      final headers = getImageRequestHeaders(imageUrl, widget.source);
                      
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        httpHeaders: headers,
                        fit: BoxFit.fitWidth,
                        width: MediaQuery.of(context).size.width,
                        placeholder: (context, url) => Container(
                          color: backgroundColor,
                          width: MediaQuery.of(context).size.width,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: progressIndicatorColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '加载中...',
                                  style: FontUtils.poppins(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: backgroundColor,
                          width: MediaQuery.of(context).size.width,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: textColor,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '图片加载失败',
                                  style: FontUtils.poppins(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}