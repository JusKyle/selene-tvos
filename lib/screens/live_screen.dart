import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/live_service.dart';
import '../models/live_channel.dart';
import '../models/live_source.dart';
import '../utils/font_utils.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';
import 'live_player_screen.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_focus_grid.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen>
    with SingleTickerProviderStateMixin {
  List<LiveChannelGroup> _channelGroups = [];
  List<LiveSource> _liveSources = [];
  LiveSource? _currentSource;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isInitialLoad = true; // 标记是否是首次加载
  String? _errorMessage;
  String _selectedGroup = '全部';
  LiveChannel? _lastPlayedChannel; // 最近播放的频道（tvOS 绿色高亮）
  final ScrollController _scrollController = ScrollController();
  late AnimationController _refreshIconController;

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadChannels();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshIconController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!mounted) return;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadChannels({LiveSource? source}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. 获取所有直播源
      final liveSources = await LiveService.getLiveSources();
      if (!mounted) return;

      if (liveSources.isEmpty) {
        setState(() {
          _errorMessage = '暂无直播源';
          _isLoading = false;
          _isInitialLoad = false;
          _liveSources = [];
          _currentSource = null;
        });
        return;
      }

      // 2. 确定要使用的直播源
      final targetSource = source ?? _currentSource ?? liveSources.first;

      // 在确定加载源后立即展示源筛选（更新状态）
      if (mounted) {
        setState(() {
          _liveSources = liveSources;
          _currentSource = targetSource;
          _isInitialLoad = false;
        });
      }

      // 3. 获取该直播源的频道列表
      final channels = await LiveService.getLiveChannels(targetSource.key);
      if (!mounted) return;

      if (channels.isEmpty) {
        setState(() {
          _errorMessage = '该直播源暂无频道';
          _isLoading = false;
        });
        return;
      }

      // 4. 按 group 进行聚类
      final Map<String, List<LiveChannel>> groupedChannels = {};
      for (var channel in channels) {
        final groupName = channel.group.isEmpty ? '未分组' : channel.group;
        if (!groupedChannels.containsKey(groupName)) {
          groupedChannels[groupName] = [];
        }
        groupedChannels[groupName]!.add(channel);
      }

      // 5. 转换为 LiveChannelGroup 列表
      final groups = groupedChannels.entries
          .map((entry) => LiveChannelGroup(
                name: entry.key,
                channels: entry.value,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _channelGroups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  Future<void> refreshChannels() async {
    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    // 开始旋转动画
    _refreshIconController.repeat();

    try {
      LiveService.clearAllChannelsAndEpgCache();
      // 1. 重新获取所有直播源
      final liveSources = await LiveService.getLiveSources(forceRefresh: true);
      if (!mounted) return;

      if (liveSources.isEmpty) {
        setState(() {
          _errorMessage = '暂无直播源';
          _liveSources = [];
          _currentSource = null;
        });
        return;
      }

      // 2. 检查当前源是否还存在
      LiveSource? targetSource;
      if (_currentSource != null) {
        // 尝试在新的源列表中找到当前源
        try {
          targetSource = liveSources.firstWhere(
            (source) => source.key == _currentSource!.key,
          );
        } catch (e) {
          // 当前源不存在，使用第一个源
          targetSource = liveSources.first;
          if (mounted) {
            _showMessage('当前源已不存在，已切换到 ${targetSource.name}');
          }
        }
      } else {
        // 没有当前源，使用第一个源
        targetSource = liveSources.first;
      }

      // 3. 获取目标源的频道列表
      final channels = await LiveService.getLiveChannels(targetSource.key);
      if (!mounted) return;

      if (channels.isEmpty) {
        setState(() {
          _errorMessage = '该直播源暂无频道';
          _liveSources = liveSources;
          _currentSource = targetSource;
        });
        return;
      }

      // 4. 按 group 进行聚类
      final Map<String, List<LiveChannel>> groupedChannels = {};
      for (var channel in channels) {
        final groupName = channel.group.isEmpty ? '未分组' : channel.group;
        if (!groupedChannels.containsKey(groupName)) {
          groupedChannels[groupName] = [];
        }
        groupedChannels[groupName]!.add(channel);
      }

      // 5. 转换为 LiveChannelGroup 列表
      final groups = groupedChannels.entries
          .map((entry) => LiveChannelGroup(
                name: entry.key,
                channels: entry.value,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _channelGroups = groups;
          _liveSources = liveSources;
          _currentSource = targetSource;
        });
        // _showMessage('刷新成功');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '刷新失败: $e';
        });
        _showMessage('刷新失败: $e');
      }
    } finally {
      // 停止旋转动画
      if (mounted) {
        _refreshIconController.stop();
        _refreshIconController.reset();
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3498DB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<LiveChannel> _getFilteredChannels() {
    if (_selectedGroup == '全部') {
      return _channelGroups.expand((g) => g.channels).toList();
    } else {
      return _channelGroups
          .firstWhere((g) => g.name == _selectedGroup,
              orElse: () => LiveChannelGroup(name: '', channels: []))
          .channels;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final column = Column(
          children: [
            _buildTVTopBar(themeService),
            Expanded(
              child: _isRefreshing
                  ? _buildRefreshingView(themeService)
                  : _isLoading
                      ? _buildLoadingView(themeService)
                      : _errorMessage != null
                          ? _buildErrorView(themeService)
                          : _buildTVChannelList(themeService),
            ),
          ],
        );

        // tvOS：外层 Focus 遍历组，串联顶部筛选栏与频道列表
        return FocusTraversalGroup(
          policy: TVGridFocusTraversal(),
          child: column,
        );
      },
    );
  }


  Widget _buildLoadingView(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF27ae60)),
          ),
          const SizedBox(height: 16),
          Text(
            '加载中...',
            style: FontUtils.poppins(
              color: themeService.isDarkMode
                  ? const Color(0xFFb0b0b0)
                  : const Color(0xFF7f8c8d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshingView(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF27ae60)),
          ),
          const SizedBox(height: 16),
          Text(
            '刷新中...',
            style: FontUtils.poppins(
              color: themeService.isDarkMode
                  ? const Color(0xFFb0b0b0)
                  : const Color(0xFF7f8c8d),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: themeService.isDarkMode
                ? const Color(0xFF666666)
                : const Color(0xFF95a5a6),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '加载失败',
            style: FontUtils.poppins(
              color: themeService.isDarkMode
                  ? const Color(0xFFb0b0b0)
                  : const Color(0xFF7f8c8d),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: refreshChannels,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27ae60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              '刷新',
              style: FontUtils.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }


  // ---- tvOS 分支 ----

  /// tvOS 顶部筛选栏：直播源 + 分组 pill 横向 Focus 遍历
  Widget _buildTVTopBar(ThemeService themeService) {
    final allGroups = ['全部', ..._channelGroups.map((g) => g.name)];
    final showSourceFilter = _liveSources.length > 1;
    final showGroupFilter = !_isInitialLoad && _channelGroups.isNotEmpty;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: FocusTraversalGroup(
        policy: TVGridFocusTraversal(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 直播源筛选（只有多个源时显示）
              if (showSourceFilter) ...[
                _buildTVFilterLabel('直播源', themeService),
                for (final source in _liveSources)
                  _buildTVFilterPill(
                    label: source.name,
                    isSelected: source.key == _currentSource?.key,
                    onTap: () {
                      final target = source;
                      setState(() {
                        _currentSource = target;
                        _selectedGroup = '全部';
                      });
                      _loadChannels(source: target);
                      _scrollToTop();
                    },
                    themeService: themeService,
                  ),
                const SizedBox(width: 24),
              ],
              // 分组筛选
              if (showGroupFilter) ...[
                _buildTVFilterLabel('分组', themeService),
                for (final group in allGroups)
                  _buildTVFilterPill(
                    label: group,
                    isSelected: group == _selectedGroup,
                    onTap: () {
                      setState(() {
                        _selectedGroup = group;
                      });
                      _scrollToTop();
                    },
                    themeService: themeService,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTVFilterLabel(String text, ThemeService themeService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: FontUtils.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: themeService.isDarkMode
              ? const Color(0xFF999999)
              : const Color(0xFF7f8c8d),
        ),
      ),
    );
  }

  Widget _buildTVFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeService themeService,
  }) {
    final bool isDefault = label == '全部';
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: TVFocusableWidget(
        scale: 1.06,
        borderWidth: 2.0,
        borderColor: isSelected ? const Color(0xFF27ae60) : Colors.white,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF27ae60).withValues(alpha: 0.25)
                : (themeService.isDarkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 14,
              fontWeight: isSelected || isDefault
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF27ae60)
                  : (themeService.isDarkMode
                      ? Colors.white
                      : const Color(0xFF2c3e50)),
            ),
          ),
        ),
      ),
    );
  }

  /// tvOS：左右方向键切换分组
  void _switchTVGroup(int delta) {
    if (_channelGroups.isEmpty) return;
    final allGroups = ['全部', ..._channelGroups.map((g) => g.name)];
    final currentIndex = allGroups.indexOf(_selectedGroup);
    if (currentIndex == -1) return;
    final newIndex = (currentIndex + delta) % allGroups.length;
    final target = allGroups[newIndex < 0 ? newIndex + allGroups.length : newIndex];
    if (target == _selectedGroup) return;
    setState(() {
      _selectedGroup = target;
    });
    _scrollToTop();
  }

  /// tvOS 频道列表：TVFocusableWidget 纵向导航，左右键切换分组
  Widget _buildTVChannelList(ThemeService themeService) {
    final channels = _getFilteredChannels();

    if (channels.isEmpty) {
      return Center(
        child: Text(
          '暂无频道',
          style: FontUtils.poppins(
            color: themeService.isDarkMode
                ? const Color(0xFFb0b0b0)
                : const Color(0xFF7f8c8d),
          ),
        ),
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _switchTVGroup(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _switchTVGroup(1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TVFocusGrid(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            return _buildTVChannelCard(
              channels[index],
              themeService,
              autofocus: index == 0,
            );
          },
        ),
      ),
    );
  }

  /// tvOS 频道卡片：当前频道绿色高亮，Focus 时白色边框 + 缩放
  Widget _buildTVChannelCard(
    LiveChannel channel,
    ThemeService themeService, {
    bool autofocus = false,
  }) {
    final bool isCurrent = _lastPlayedChannel?.id == channel.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: TVFocusableWidget(
        autofocus: autofocus,
        scale: 1.03,
        borderColor: isCurrent ? const Color(0xFF27ae60) : Colors.white,
        onTap: () {
          setState(() {
            _lastPlayedChannel = channel;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LivePlayerScreen(
                channel: channel,
                source: _currentSource!,
              ),
            ),
          ).then((_) {
            if (mounted) {
              _loadChannels();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: themeService.isDarkMode
                ? (isCurrent
                    ? const Color(0xFF27ae60).withValues(alpha: 0.18)
                    : const Color(0xFF1e1e1e))
                : (isCurrent
                    ? const Color(0xFF27ae60).withValues(alpha: 0.12)
                    : Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // 台标
              SizedBox(
                width: 56,
                height: 28,
                child: channel.logo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          channel.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildTVChannelLogoFallback(themeService),
                          loadingBuilder: (context, child, loadingProgress) =>
                              _buildTVChannelLogoFallback(themeService),
                        ),
                      )
                    : _buildTVChannelLogoFallback(themeService),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: FontUtils.poppins(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w500,
                        color: isCurrent
                            ? const Color(0xFF27ae60)
                            : (themeService.isDarkMode
                                ? Colors.white
                                : const Color(0xFF2c3e50)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.group,
                      style: FontUtils.poppins(
                        fontSize: 12,
                        color: themeService.isDarkMode
                            ? const Color(0xFF999999)
                            : const Color(0xFF7f8c8d),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTVChannelLogoFallback(ThemeService themeService) {
    return Container(
      decoration: BoxDecoration(
        color: themeService.isDarkMode
            ? const Color(0xFF2a2a2a)
            : const Color(0xFFc0c0c0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.tv,
        size: 18,
        color: Color(0xFF95a5b0),
      ),
    );
  }

}

