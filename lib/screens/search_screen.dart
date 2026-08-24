import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/page_cache_service.dart';
import '../services/theme_service.dart';
import '../services/sse_search_service.dart';
import '../models/search_result.dart';
import '../models/video_info.dart';
import '../widgets/video_menu_bottom_sheet.dart';
import '../widgets/custom_switch.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_focus_grid.dart';
import '../widgets/tv_fullscreen_panel.dart';
import '../widgets/favorites_grid.dart';
import '../widgets/search_result_agg_grid.dart';
import '../widgets/search_results_grid.dart';
import '../widgets/filter_pill_hover.dart';
import '../widgets/main_layout.dart';
import '../utils/font_utils.dart';
import 'player_screen.dart';

enum SortOrder { none, asc, desc }

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  List<String> _searchHistory = [];
  final List<SearchResult> _searchResults = [];
  bool _hasSearched = false;
  bool _hasReceivedStart = false; // 是否已收到start消息
  String? _searchError;
  SearchProgress? _searchProgress;
  Timer? _updateTimer; // 用于防抖的定时器
  bool _useAggregatedView = true; // 是否使用聚合视图，默认开启

  // 筛选和排序状态
  String _selectedSource = 'all';
  String _selectedYear = 'all';
  String _selectedTitle = 'all';
  SortOrder _yearSortOrder = SortOrder.none;

  late SSESearchService _searchService;
  StreamSubscription<List<SearchResult>>? _incrementalResultsSubscription;
  StreamSubscription<SearchProgress>? _progressSubscription;
  StreamSubscription<String>? _errorSubscription;

  List<SearchResult> get _filteredSearchResults {
    List<SearchResult> results = List.from(_searchResults);

    // Source filter
    if (_selectedSource != 'all') {
      results = results.where((r) => r.sourceName == _selectedSource).toList();
    }

    // Year filter
    if (_selectedYear != 'all') {
      results = results.where((r) => r.year == _selectedYear).toList();
    }

    // Title filter
    if (_selectedTitle != 'all') {
      results = results.where((r) => r.title == _selectedTitle).toList();
    }

    // Year sort
    if (_yearSortOrder != SortOrder.none) {
      results.sort((a, b) {
        final yearAIsNum = int.tryParse(a.year) != null;
        final yearBIsNum = int.tryParse(b.year) != null;

        if (yearAIsNum && !yearBIsNum) {
          return -1; // a (数字) 在 b (非数字) 前面
        }
        if (!yearAIsNum && yearBIsNum) {
          return 1; // b (数字) 在 a (非数字) 前面
        }
        if (!yearAIsNum && !yearBIsNum) {
          return 0; // 都是非数字，保持顺序
        }

        final yearA = int.parse(a.year);
        final yearB = int.parse(b.year);

        if (_yearSortOrder == SortOrder.desc) {
          return yearB.compareTo(yearA);
        } else {
          // SortOrder.asc
          return yearA.compareTo(yearB);
        }
      });
    }

    return results;
  }

  @override
  void initState() {
    super.initState();

    _searchService = SSESearchService();
    _setupSearchListeners();
    _loadSearchHistory();

    // 进入搜索页面时自动聚焦搜索框
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _incrementalResultsSubscription?.cancel();
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    _updateTimer?.cancel();
    _searchService.dispose();
    super.dispose();
  }

  /// 设置搜索监听器
  void _setupSearchListeners() {
    // 取消之前的监听器
    _incrementalResultsSubscription?.cancel();
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();

    // 监听增量搜索结果
    _incrementalResultsSubscription =
        _searchService.incrementalResultsStream.listen((incrementalResults) {
      if (mounted && incrementalResults.isNotEmpty) {
        // 将增量结果添加到现有结果列表中
        _searchResults.addAll(incrementalResults);

        // 使用防抖机制，避免过于频繁的UI更新，同时确保用户交互不受影响
        _updateTimer?.cancel();
        _updateTimer = Timer(const Duration(milliseconds: 50), () {
          if (mounted) {
            // 使用 scheduleMicrotask 确保UI更新在下一个微任务中执行，不阻塞用户交互
            scheduleMicrotask(() {
              if (mounted) {
                setState(() {
                  // 触发UI更新
                });
              }
            });
          }
        });
      }
    });

    // 监听搜索进度
    _progressSubscription = _searchService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _searchProgress = progress;
          _hasReceivedStart = true;
        });
      }
    });

    // 监听搜索错误
    _errorSubscription = _searchService.errorStream.listen((error) {
      if (mounted) {
        // 检查是否是连接关闭错误，如果是则忽略
        final errorString = error.toLowerCase();
        if (errorString.contains('connection closed') ||
            errorString.contains('clientexception') ||
            errorString.contains('connection terminated')) {
          // 连接被关闭，这是正常情况，不显示错误
          return;
        }

        setState(() {
          _searchError = error;
        });
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    // 首先尝试从缓存加载数据
    try {
      final result = await PageCacheService().getSearchHistory(context);
      if (mounted) {
        setState(() {
          _searchHistory = result.success ? (result.data ?? []) : [];
        });
      }
    } catch (e) {
      // 缓存加载失败，设置为空
      if (mounted) {
        setState(() {
          _searchHistory = [];
        });
      }
    }
  }

  Future<void> _refreshSearchHistory() async {
    try {
      // 刷新缓存数据
      await PageCacheService().refreshSearchHistory(context);
      if (!mounted) return;

      // 重新获取搜索历史数据
      final result = await PageCacheService().getSearchHistory(context);
      if (mounted) {
        setState(() {
          _searchHistory = result.success ? (result.data ?? []) : [];
        });
      }
    } catch (e) {
      // 错误处理，保持当前显示的内容
    }
  }

  /// 异步刷新收藏夹数据
  Future<void> _refreshFavorites() async {
    try {
      // 刷新收藏夹缓存数据
      await PageCacheService().refreshFavorites(context);
    } catch (e) {
      // 错误处理，静默处理
    }
  }

  /// 添加搜索历史（本地状态、缓存、服务器）
  void addSearchHistory(String query) {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();

    // 立即添加到缓存
    PageCacheService().addSearchHistory(trimmedQuery, context);

    // 立即更新本地状态和UI
    if (mounted) {
      setState(() {
        // 检查是否已存在相同的搜索词（区分大小写）
        final existingIndex =
            _searchHistory.indexWhere((item) => item == trimmedQuery);

        if (existingIndex == -1) {
          // 不存在，添加到列表开头
          _searchHistory.insert(0, trimmedQuery);
        } else {
          // 已存在，移动到开头（保持原始大小写）
          final existingItem = _searchHistory[existingIndex];
          _searchHistory.removeAt(existingIndex);
          _searchHistory.insert(0, existingItem);
        }
      });
    }
  }

  /// 显示清空确认弹窗
  void _showClearConfirmation() {
    // tvOS 使用全屏面板替代 showDialog
    TVFullscreenPanel.show<void>(
      context,
      title: '清空搜索历史',
      items: [
        TVFocusableWidget(
          onTap: () {
            Navigator.of(context).pop();
            _clearSearchHistory();
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFe74c3c),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '确认清空',
                  style: FontUtils.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        TVFocusableWidget(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '取消',
                style: FontUtils.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 清空搜索历史
  Future<void> _clearSearchHistory() async {
    try {
      final result = await PageCacheService().clearSearchHistory(context);

      if (result.success) {
        // 立即清空本地状态
        if (mounted) {
          setState(() {
            _searchHistory.clear();
          });
        }
      } else {
        // 异常时异步刷新搜索历史以恢复数据
        _refreshSearchHistory();
      }
    } catch (e) {
      // 异常时异步刷新搜索历史以恢复数据
      _refreshSearchHistory();
    }
  }

  /// 删除单个搜索历史
  Future<void> _deleteSearchHistory(String historyItem) async {
    try {
      final result =
          await PageCacheService().deleteSearchHistory(historyItem, context);

      if (result.success) {
        // 立即从UI中移除
        if (mounted) {
          setState(() {
            _searchHistory.remove(historyItem);
          });
        }
      } else {
        // API调用失败，异步刷新搜索历史以恢复数据
        _refreshSearchHistory();
      }
    } catch (e) {
      // 异常时异步刷新搜索历史以恢复数据
      _refreshSearchHistory();
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _searchQuery = query.trim();
      _hasSearched = true;
      _hasReceivedStart = false; // 重置start状态
      _searchError = null;
      _searchResults.clear();
      _searchProgress = null; // 清空进度信息
      _useAggregatedView = true; // 默认开启聚合
      // 重置筛选和排序
      _selectedSource = 'all';
      _selectedYear = 'all';
      _selectedTitle = 'all';
      _yearSortOrder = SortOrder.none;
    });

    // 添加到搜索历史
    addSearchHistory(_searchQuery);

    // 搜索框失焦
    _searchFocusNode.unfocus();

    try {
      // 开始 SSE 搜索
      await _searchService.startSearch(_searchQuery);

      // 重新设置监听器，确保流控制器已初始化
      _setupSearchListeners();
    } catch (e) {
      if (mounted) {
        // 检查是否是连接关闭错误，如果是则忽略
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('connection closed') ||
            errorString.contains('clientexception') ||
            errorString.contains('connection terminated')) {
          // 连接被关闭，这是正常情况，不显示错误
          return;
        }

        setState(() {
          _searchError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        final ml = MainLayout(
          content: Container(
            color: themeService.isDarkMode
                ? const Color(0xFF121212)
                : const Color(0xFFf5f5f5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_hasSearched) ...[
                  // 搜索错误提示
                  if (_searchError != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildSearchError(themeService),
                    ),
                  // 搜索历史（只有在从未搜索过时显示）
                  Expanded(
                    child: _buildSearchHistory(themeService),
                  ),
                ],
                if (_hasSearched) ...[
                  // 搜索结果区域，不添加额外padding
                  Expanded(
                    child: _buildSearchResults(themeService),
                  ),
                ],
              ],
            ),
          ),
          currentBottomNavIndex: -1, // 不选中任何底部导航项
          onBottomNavChanged: (index) {
            // 点击底部导航时关闭搜索页面
            Navigator.pop(context);
          },
          selectedTopTab: '',
          onTopTabChanged: (tab) {},
          showBottomNav: false, // 不显示底部导航栏
          isSearchMode: true,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          searchQuery: _searchQuery,
          onSearchQueryChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onSearchSubmitted: (value) {
            _performSearch(value);
          },
          onClearSearch: () {
            setState(() {
              _searchQuery = '';
              _searchController.clear();
              _hasSearched = false;
              _hasReceivedStart = false;
              _searchResults.clear();
              _searchError = null;
              _searchProgress = null;
              _searchService.stopSearch();
            });
          },
          onHomeTap: () {
            Navigator.pop(context);
          },
        );
        return ml;
      },
    );
  }

  Widget _buildSearchHistory(ThemeService themeService) {
    // 如果没有搜索历史，显示空状态
    if (_searchHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 120.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.history,
                size: 80,
                color: themeService.isDarkMode
                    ? const Color(0xFF444444)
                    : const Color(0xFFbdc3c7),
              ),
              const SizedBox(height: 24),
              Text(
                '暂无搜索历史',
                style: FontUtils.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: themeService.isDarkMode
                      ? const Color(0xFF666666)
                      : const Color(0xFF7f8c8d),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '开始搜索你喜欢的内容吧',
                style: FontUtils.poppins(
                  fontSize: 14,
                  color: themeService.isDarkMode
                      ? const Color(0xFF555555)
                      : const Color(0xFF95a5a6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // tvOS 使用纵向 Focus 列表，长按删除改为 Menu 键删除
    return _buildTVSearchHistory(themeService);
  }

  /// tvOS 搜索历史：纵向 Focus 列表，Select 搜索，Menu 键删除
  Widget _buildTVSearchHistory(ThemeService themeService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 22.0, right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: FontUtils.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeService.isDarkMode
                      ? const Color(0xFFffffff)
                      : const Color(0xFF2c3e50),
                ),
              ),
              // 清空按钮：Focus 触发清空确认面板
              TVFocusableWidget(
                onTap: _showClearConfirmation,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '清空',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFFb0b0b0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TVFocusGrid(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final history = _searchHistory[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildTVHistoryItem(themeService, history),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// tvOS 单个搜索历史项：Select 搜索，Menu 删除
  Widget _buildTVHistoryItem(ThemeService themeService, String history) {
    return TVFocusableWidget(
      onTap: () {
        _searchController.text = history;
        setState(() {
          _searchQuery = history;
        });
        _performSearch(history);
      },
      onMenu: () {
        _deleteSearchHistory(history);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:
              themeService.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: themeService.isDarkMode
                ? const Color(0xFF333333)
                : const Color(0xFFe9ecef),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.history,
              size: 18,
              color: themeService.isDarkMode
                  ? const Color(0xFFb0b0b0)
                  : const Color(0xFF7f8c8d),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                history,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FontUtils.poppins(
                  fontSize: 16,
                  color: themeService.isDarkMode
                      ? const Color(0xFFffffff)
                      : const Color(0xFF2c3e50),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close,
              size: 16,
              color: themeService.isDarkMode
                  ? const Color(0xFF666666)
                  : const Color(0xFF95a5a6),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建搜索错误显示
  Widget _buildSearchError(ThemeService themeService) {
    final error = _searchError;
    if (error == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFe74c3c).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFe74c3c).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFe74c3c),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: FontUtils.poppins(
                fontSize: 14,
                color: const Color(0xFFe74c3c),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchError = null;
              });
            },
            child: Text(
              '重试',
              style: FontUtils.poppins(
                fontSize: 12,
                color: const Color(0xFFe74c3c),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ThemeService themeService) {
    // 如果已搜索过，总是显示搜索结果区域
    if (_hasSearched) {
      return _buildSearchResultsList(themeService);
    }

    // 默认返回空容器
    return const SizedBox.shrink();
  }

  Widget _buildSearchResultsList(ThemeService themeService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // 标题行 - 有padding
        Padding(
          padding: const EdgeInsets.only(left: 22.0, right: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline, // 基线对齐
            textBaseline: TextBaseline.alphabetic, // 使用字母基线
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '搜索结果',
                    style: FontUtils.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: themeService.isDarkMode
                          ? const Color(0xFFffffff)
                          : const Color(0xFF2c3e50),
                    ),
                  ),
                  if (_hasSearched) ...[
                    const SizedBox(width: 8),
                    if (_hasReceivedStart)
                      Text(
                        _getProgressText(),
                        style: FontUtils.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: themeService.isDarkMode
                              ? const Color(0xFFb0b0b0)
                              : const Color(0xFF7f8c8d),
                        ),
                      )
                  ],
                ],
              ),
              // 聚合开关
              if (_hasSearched && _searchResults.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '聚合',
                      style: FontUtils.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: themeService.isDarkMode
                            ? const Color(0xFFffffff)
                            : const Color(0xFF2c3e50),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Builder(builder: (context) {
                      final switchWidget = Transform.translate(
                        offset: const Offset(0, 1.0),
                        child: CustomSwitch(
                          value: _useAggregatedView,
                          onChanged: (value) {
                            setState(() {
                              _useAggregatedView = value;
                            });
                          },
                          activeColor: const Color(0xFF27ae60),
                          inactiveColor: themeService.isDarkMode
                              ? const Color(0xFF444444)
                              : const Color(0xFFcccccc),
                          width: 32,
                          height: 16,
                        ),
                      );
                      // tvOS 上聚合开关需要可 Focus
                      return TVFocusableWidget(
                        onTap: () {
                          setState(() {
                            _useAggregatedView = !_useAggregatedView;
                          });
                        },
                        child: switchWidget,
                      );
                    }),
                  ],
                ),
            ],
          ),
        ),
        // 根据搜索状态显示不同内容
        if (_hasSearched && _searchResults.isEmpty)
          Expanded(
            child: Center(
              child: _buildEmptyStateContent(),
            ),
          )
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 靠左对齐
              children: [
                // 筛选器行
                if (_hasSearched && _searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 22.0, right: 16.0),
                    child: _buildFilterSection(themeService),
                  ),
                ],
                const SizedBox(height: 8),
                // Grid区域 - 无padding，占满宽度
                Expanded(
                  child: _useAggregatedView
                      ? SearchResultAggGrid(
                          key: const ValueKey('agg_grid'),
                          results: _filteredSearchResults,
                          themeService: themeService,
                          onVideoTap: _onVideoTap,
                          onGlobalMenuAction: _onGlobalMenuAction,
                          onSourceSelected: (SearchResult result) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PlayerScreen(
                                          source: result.source,
                                          id: result.id,
                                          year: result.year,
                                          title: result.title,
                                          stitle: _searchQuery,
                                          stype: result.episodes.length > 1
                                              ? 'tv'
                                              : 'movie',
                                        )));
                          },
                          hasReceivedStart: _hasReceivedStart,
                        )
                      : SearchResultsGrid(
                          key: const ValueKey('list_grid'),
                          results: _filteredSearchResults,
                          themeService: themeService,
                          onVideoTap: _onVideoTap,
                          onGlobalMenuAction: _onGlobalMenuAction,
                          hasReceivedStart: _hasReceivedStart,
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _onVideoTap(VideoInfo videoInfo) {
    _onGlobalMenuAction(videoInfo, VideoMenuAction.play);
  }

  String _getProgressText() {
    if (_searchProgress != null) {
      return '${_searchProgress!.completedSources}/${_searchProgress!.totalSources}';
    }
    return '0/0';
  }

  Widget _buildEmptyStateContent() {
    final bool isSearchFinished = _hasReceivedStart &&
        _searchProgress != null &&
        _searchProgress!.completedSources >= _searchProgress!.totalSources;

    if (isSearchFinished) {
      // 未找到结果
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.folderSearch,
            size: 80,
            color: Color(0xFFbdc3c7),
          ),
          const SizedBox(height: 24),
          Text(
            '未找到结果',
            style: FontUtils.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7f8c8d),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '请尝试更换关键词',
            style: FontUtils.poppins(
              fontSize: 14,
              color: const Color(0xFF95a5a6),
            ),
          ),
        ],
      );
    } else {
      // 搜索中...
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.search,
            size: 80,
            color: Color(0xFFbdc3c7),
          ),
          const SizedBox(height: 24),
          Text(
            '搜索中...',
            style: FontUtils.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7f8c8d),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '聚合搜索中，请稍候',
            style: FontUtils.poppins(
              fontSize: 14,
              color: const Color(0xFF95a5a6),
            ),
          ),
        ],
      );
    }
  }

  /// 处理视频菜单操作
  void _onGlobalMenuAction(VideoInfo videoInfo, VideoMenuAction action) {
    final stitle = _searchQuery;
    switch (action) {
      case VideoMenuAction.play:
        if (_useAggregatedView) {
          // 聚合卡片，只传递title和stitle，并从id中解析stype
          final parts = videoInfo.id.split('_');
          final type = parts.length > 2 ? parts.last : null;
          final year = parts.length > 1 ? parts[1] : null;

          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                        title: videoInfo.title,
                        stitle: stitle,
                        stype: type,
                        year: year,
                      )));
        } else {
          // 非聚合卡片，传递完整信息
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                        source: videoInfo.source,
                        id: videoInfo.id,
                        year: videoInfo.year,
                        title: videoInfo.title,
                        stype: videoInfo.totalEpisodes > 1 ? 'tv' : 'movie',
                        stitle: stitle,
                      )));
        }
        break;
      case VideoMenuAction.favorite:
        // 收藏
        _handleFavorite(videoInfo);
        break;
      case VideoMenuAction.unfavorite:
        // 取消收藏
        _handleUnfavorite(videoInfo);
        break;
      case VideoMenuAction.deleteRecord:
        // 搜索场景不支持删除记录
        break;
      case VideoMenuAction.doubanDetail:
        // 豆瓣详情 - 已在组件内部处理URL跳转
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '正在打开豆瓣详情: ${videoInfo.title}',
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
        break;
      case VideoMenuAction.bangumiDetail:
        // Bangumi详情 - 已在组件内部处理URL跳转
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '正在打开 Bangumi 详情: ${videoInfo.title}',
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
        break;
    }
  }

  /// 处理收藏
  Future<void> _handleFavorite(VideoInfo videoInfo) async {
    try {
      // 构建收藏数据
      final favoriteData = {
        'cover': videoInfo.cover,
        'save_time': DateTime.now().millisecondsSinceEpoch,
        'source_name': videoInfo.sourceName,
        'title': videoInfo.title,
        'total_episodes': videoInfo.totalEpisodes,
        'year': videoInfo.year,
      };

      // 使用统一的收藏方法（包含缓存操作和API调用）
      final result = await PageCacheService()
          .addFavorite(videoInfo.source, videoInfo.id, favoriteData, context);

      if (result.success) {
        // 通知UI刷新收藏状态
        if (mounted) {
          setState(() {});
        }
      } else {
        // 显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? '收藏失败',
                style: FontUtils.poppins(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFe74c3c),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        _refreshFavorites();
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '收藏失败: ${e.toString()}',
              style: FontUtils.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFe74c3c),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      _refreshFavorites();
    }
  }

  /// 处理取消收藏
  Future<void> _handleUnfavorite(VideoInfo videoInfo) async {
    try {
      // 先立即从UI中移除该项目
      FavoritesGrid.removeFavoriteFromUI(videoInfo.source, videoInfo.id);

      // 通知继续观看组件刷新收藏状态
      if (mounted) {
        setState(() {});
      }

      // 使用统一的取消收藏方法（包含缓存操作和API调用）
      final result = await PageCacheService()
          .removeFavorite(videoInfo.source, videoInfo.id, context);

      if (!result.success) {
        // 显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? '取消收藏失败',
                style: FontUtils.poppins(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFe74c3c),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
        // API失败时重新刷新缓存以恢复数据
        _refreshFavorites();
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '取消收藏失败: ${e.toString()}',
              style: FontUtils.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFe74c3c),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      // 异常时重新刷新缓存以恢复数据
      _refreshFavorites();
    }
  }

  // 筛选器相关方法

  List<SelectorOption> get _sourceOptions {
    final sources = _searchResults.map((r) => r.sourceName).toSet().toList();
    sources.sort();
    final options =
        sources.map((s) => SelectorOption(label: s, value: s)).toList();
    return [
      const SelectorOption(label: '全部来源', value: 'all'),
      ...options,
    ];
  }

  List<SelectorOption> get _yearOptions {
    final years = _searchResults
        .map((r) => r.year)
        .where((y) => y.isNotEmpty)
        .toSet()
        .toList();
    years.sort((a, b) => b.compareTo(a)); // Sort descending
    final options =
        years.map((y) => SelectorOption(label: y, value: y)).toList();
    return [
      const SelectorOption(label: '全部年份', value: 'all'),
      ...options,
    ];
  }

  List<SelectorOption> get _titleOptions {
    final titles = _searchResults.map((r) => r.title).toSet().toList();
    titles.sort();
    final options =
        titles.map((t) => SelectorOption(label: t, value: t)).toList();
    return [
      const SelectorOption(label: '全部标题', value: 'all'),
      ...options,
    ];
  }

  Widget _buildFilterSection(ThemeService themeService) {
    // tvOS 使用 Focus 包裹的筛选控件
    return _buildTVFilterSection(themeService);
  }

  /// tvOS 筛选器：全部控件用 TVFocusableWidget 包裹，确保 Focus 导航
  Widget _buildTVFilterSection(ThemeService themeService) {
    return TVFocusGrid(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTVFilterPill('来源', _sourceOptions, _selectedSource,
                (newValue) {
              setState(() {
                _selectedSource = newValue;
              });
            }, isFirst: true),
            _buildTVFilterPill('标题', _titleOptions, _selectedTitle,
                (newValue) {
              setState(() {
                _selectedTitle = newValue;
              });
            }),
            _buildTVFilterPill('年份', _yearOptions, _selectedYear, (newValue) {
              setState(() {
                _selectedYear = newValue;
              });
            }),
            _buildTVYearSortButton(),
          ],
        ),
      ),
    );
  }

  /// tvOS 筛选胶囊：Select 打开全屏筛选面板
  Widget _buildTVFilterPill(
      String title,
      List<SelectorOption> options,
      String selectedValue,
      ValueChanged<String> onSelected,
      {bool isFirst = false}) {
    final isDefault = selectedValue == 'all';
    return TVFocusableWidget(
      onTap: () {
        _showFilterOptions(context, title, options, selectedValue, onSelected);
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(isFirst ? 0 : 8, 6, 8, 6),
        child: Row(
          children: [
            Text(
              title,
              style: FontUtils.poppins(
                fontSize: 13,
                color: isDefault
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : const Color(0xFF27AE60),
                fontWeight:
                    isDefault ? FontWeight.normal : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isDefault
                  ? Theme.of(context).textTheme.bodySmall?.color
                  : const Color(0xFF27AE60),
            ),
          ],
        ),
      ),
    );
  }

  /// tvOS 年份排序按钮：Select 循环切换排序
  Widget _buildTVYearSortButton() {
    IconData icon;
    switch (_yearSortOrder) {
      case SortOrder.desc:
        icon = LucideIcons.arrowDown10;
        break;
      case SortOrder.asc:
        icon = LucideIcons.arrowUp10;
        break;
      case SortOrder.none:
        icon = LucideIcons.arrowDownUp;
        break;
    }
    final isDefault = _yearSortOrder == SortOrder.none;
    return TVFocusableWidget(
      onTap: () {
        setState(() {
          if (_yearSortOrder == SortOrder.none) {
            _yearSortOrder = SortOrder.desc;
          } else if (_yearSortOrder == SortOrder.desc) {
            _yearSortOrder = SortOrder.asc;
          } else {
            _yearSortOrder = SortOrder.none;
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Text(
              '年份',
              style: FontUtils.poppins(
                fontSize: 13,
                color: isDefault
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : const Color(0xFF27AE60),
                fontWeight:
                    isDefault ? FontWeight.normal : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 16,
              color: isDefault
                  ? Theme.of(context).textTheme.bodySmall?.color
                  : const Color(0xFF27AE60),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(
      BuildContext context,
      String title,
      List<SelectorOption> options,
      String selectedValue,
      ValueChanged<String> onSelected) {
    // tvOS 使用全屏面板替代底部弹出/对话框
    _showTVFilterOptions(context, title, options, selectedValue, onSelected);
  }

  /// tvOS 筛选选项：使用全屏面板展示
  void _showTVFilterOptions(
      BuildContext context,
      String title,
      List<SelectorOption> options,
      String selectedValue,
      ValueChanged<String> onSelected) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    TVFullscreenPanel.show<void>(
      context,
      title: title,
      items: options.map((option) {
        final isSelected = option.value == selectedValue;
        return TVFocusableWidget(
          onTap: () {
            onSelected(option.value);
            Navigator.of(context).pop();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF27AE60)
                  : isDark
                      ? const Color(0xFF1e1e1e)
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF27AE60)
                    : isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFe9ecef),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: FontUtils.poppins(
                      fontSize: 16,
                      color: isSelected
                          ? Colors.white
                          : isDark
                              ? const Color(0xFFffffff)
                              : const Color(0xFF2c3e50),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

}
