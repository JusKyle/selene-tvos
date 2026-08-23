# Selene Apple TV (tvOS) 适配计划

## 当前功能清单与 tvOS 适配决策

### 一、内容浏览功能

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| 首页底部导航（6个tab：首页/电影/剧集/动漫/综艺/直播） | ✅ 保留 | 改为 Focus 横向导航 |
| 首页顶部导航（3个tab：首页/播放历史/收藏夹） | ✅ 保留 | 同上 |
| 继续观看组件 | ✅ 保留 | 卡片改为 Focus 导航 |
| 热门电影列表 | ✅ 保留 | 同上 |
| 热门剧集列表 | ✅ 保留 | 同上 |
| 新番放送列表 | ✅ 保留 | 同上 |
| 热门综艺列表 | ✅ 保留 | 同上 |
| 推荐内容列表 | ✅ 保留 | 同上 |
| 播放历史列表 | ✅ 保留 | 同上 |
| 收藏夹列表 | ✅ 保留 | 同上 |
| 电影分类页（MovieScreen） | ✅ 保留 | 含豆瓣热门电影 |
| 剧集分类页（TvScreen） | ✅ 保留 | 同上 |
| 动漫分类页（AnimeScreen） | ✅ 保留 | 同上 |
| 综艺分类页（ShowScreen） | ✅ 保留 | 同上 |
| 分类筛选（年份/来源/排序） | 🔧 适配 | 底部弹窗 → 全屏面板 |
| 下拉刷新 | ✅ 保留 | 改为 Menu 按钮触发刷新 |
| 视频卡片长按菜单 | 🔧 适配 | 长按 → Focus 状态下 Menu 按钮触发 |

### 二、搜索功能

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| 文本搜索输入 | ✅ 保留 | tvOS 自动弹出系统键盘 |
| 搜索建议 | ✅ 保留 | Focus 纵向导航 |
| 搜索历史 | ✅ 保留 | 同上 |
| 聚合搜索结果视图 | ✅ 保留 | Focus 导航 |
| SSE 流式搜索 | ✅ 保留 | 后端逻辑不变 |
| 筛选/排序（来源/年份/排序） | 🔧 适配 | 弹窗 → 全屏面板 |
| 搜索历史管理（删除/清空） | 🔧 适配 | 改为 Focus 操作 |

### 三、视频播放功能

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| media_kit 播放器 | ❌ 替换 | 改用 `video_player` (AVFoundation) |
| 自定义 HTTP 头 | ✅ 保留 | `video_player` 支持 `httpHeaders` |
| 播放/暂停/跳转 | ✅ 保留 | 改为 Siri Remote 操作 |
| 倍速播放 (0.5x-2.0x) | ✅ 保留 | 全屏面板选择 |
| 音量控制 | ❌ 移除 | 苹果遥控器硬件控制 |
| 亮度控制 | ❌ 移除 | 电视端无意义 |
| 播放进度条 | ✅ 保留 | 加粗，Focus 可操作 |
| 播放完成自动下一集 | ✅ 保留 | 逻辑不变 |
| 剧集面板 | ✅ 保留 | 全屏 Focus 网格 |
| 播放源面板 | ✅ 保留 | 同上 |
| 视频详情面板 | ✅ 保留 | 显示信息 |
| 剧集自动滚动到当前集 | ✅ 保留 | 逻辑不变 |
| 播放源速度测试 | ✅ 保留 | 逻辑不变 |
| 源切换/剧集切换加载动画 | ✅ 保留 | 视觉不变 |
| 画中画 (PiP) | 🔧 重写 | tvOS 用 AVFoundation 原生 PiP |
| 网页全屏 | ❌ 移除 | 桌面端概念，TV 无意义 |
| 播放进度自动保存 | ✅ 保留 | 逻辑不变 |
| 后台播放 | ✅ 保留 | tvOS 支持 |

### 四、直播功能

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| 直播频道列表 | ✅ 保留 | 改为 Focus 纵向导航 |
| 直播源管理 | ✅ 保留 | 同上 |
| 频道分组筛选 | ✅ 保留 | 同上 |
| EPG 节目单 | ✅ 保留 | 横向/纵向 Focus 导航 |
| 直播播放器 | ✅ 保留 | 改用 `video_player` |
| 频道切换 | ✅ 保留 | 上下方向键切换 |

### 五、用户系统

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| 服务器模式登录 | ✅ 保留 | Focus 表单 |
| 本地模式（订阅链接） | ✅ 保留 | 同上 |
| 自动登录 | ✅ 保留 | 逻辑不变 |
| 用户菜单 | 🔧 适配 | 居中弹出 → 全屏侧边栏 |
| 豆瓣数据源设置 | ✅ 保留 | 设置项 |
| 豆瓣图片源设置 | ✅ 保留 | 同上 |
| M3U8 代理 URL 设置 | ✅ 保留 | 文本输入，tvOS 键盘 |
| 优选测速开关 | ✅ 保留 | Toggle 开关 |
| 本地搜索开关 | ✅ 保留 | 同上 |
| 清除豆瓣缓存 | ✅ 保留 | 按钮操作 |
| 检查更新 | ✅ 保留 | 按钮操作 |
| 登出 | ✅ 保留 | 按钮操作 |
| 版本号/关于 | ✅ 保留 | 跳转 GitHub |

### 六、内容发现集成

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| 豆瓣电影详情 | ✅ 保留 | 数据展示，无交互 |
| 豆瓣评分显示 | ✅ 保留 | 同上 |
| 豆瓣电影排行榜 | ✅ 保留 | 列表浏览 |
| Bangumi 新番日历 | ✅ 保留 | 同上 |
| 搜索源管理 | ✅ 保留 | 后台逻辑 |

### 七、投屏/其他

| 功能 | 适配决策 | 说明 |
|------|---------|------|
| DLNA 投屏 | ❌ 移除 | Apple TV 本身就是接收端 |
| 全屏图片查看器 | ✅ 保留 | 图片浏览 |
| 图片保存到相册 | ❌ 移除 | tvOS 无相册概念 |
| 主题切换（亮/暗/跟随系统） | ✅ 保留 | 强制暗色模式（TV 最佳实践） |
| 应用更新检查 | ✅ 保留 | 通过 App Store 更新 |

### 八、平台特定功能（直接移除）

| 功能 | 适配决策 | 原因 |
|------|---------|------|
| Windows 标题栏 | ❌ 移除 | 无窗口概念 |
| macOS 透明标题栏 | ❌ 移除 | 同上 |
| macOS 窗口亮度跟随主题 | ❌ 移除 | 同上 |
| Windows 字体渲染优化 | ❌ 移除 | 使用系统字体 |
| bitsdojo_window 窗口管理 | ❌ 移除 | 无窗口 |
| macos_window_utils | ❌ 移除 | 无窗口 |
| 移动端方向锁定 | ❌ 移除 | TV 始终横屏 |
| 移动端侧滑返回 | ❌ 移除 | 用 Menu 按钮 |
| 移动端长按手势 | ❌ 移除 | 用 Focus + Select 按钮 |
| 桌面端 hover 效果 | ❌ 移除 | 替换为 Focus 高亮 |

## 需要保留但需适配的交互

| 交互方式 | 原实现 | tvOS 适配方案 |
|---------|--------|-------------|
| 点击选择 | GestureDetector.onTap | Focus + Select 按钮 |
| 右键菜单 | 长按/右键 | Focus + Menu 按钮 |
| 弹窗选择 | showModalBottomSheet | 全屏 Focus 面板 |
| 下拉刷新 | RefreshIndicator | Menu 按钮触发刷新 |
| 拖拽进度条 | 鼠标拖拽/触摸 | Siri Remote 触控板滑动 |
| 文本输入 | 键盘/触摸键盘 | tvOS 系统键盘 |
| 返回上一页 | 返回按钮/手势 | Siri Remote Menu 按钮 |
| 播放控制 | 鼠标悬浮/触摸 | Focus 自动显示 |

## 架构改动

### 新增文件
```
lib/core/platform_detector.dart    # 安全平台检测（替换 dart:io Platform）
lib/core/player_adapter.dart       # 播放器抽象接口
lib/core/video_player_adapter.dart # video_player 适配器
lib/widgets/tv_focusable.dart      # Focus 高亮通用组件
lib/widgets/tv_focus_grid.dart     # Focus 网格导航策略
lib/widgets/tv_player_controls.dart # 电视端播放控制
lib/widgets/tv_fullscreen_panel.dart # 全屏菜单面板
tvos/                              # tvOS Xcode 项目
```

### 修改文件
```
pubspec.yaml                 # 添加 video_player，移除/条件化不兼容包
lib/main.dart                # PlatformDetector 替换，tvOS 初始化
lib/utils/device_utils.dart  # 替换 Platform.is*，添加 isTVOS()
lib/services/theme_service.dart # 添加 tvTheme，守卫平台代码
lib/widgets/video_player_surface.dart # 添加 tv 枚举值
lib/widgets/video_player_widget.dart  # 播放器工厂，tv 控制分支
lib/widgets/main_layout.dart  # Focus 导航栏
lib/widgets/video_card.dart   # Focus 高亮替换 hover
lib/screens/home_screen.dart  # Focus 导航
lib/screens/search_screen.dart # Focus 输入和结果
lib/screens/player_screen.dart # tv 播放器布局
lib/screens/live_screen.dart   # Focus 频道列表
lib/screens/live_player_screen.dart # tv 直播播放器
lib/screens/login_screen.dart  # Focus 表单
```

## 实施阶段

### Phase 1: 基础架构（1-2天）
- 创建 tvos/ Xcode 项目
- 实现 PlatformDetector 替换所有 `Platform.is*`
- 添加 `video_player` 依赖，建立 PlayerAdapter 抽象
- 处理不兼容依赖的守卫

### Phase 2: 导航系统（2-3天）
- 创建 TVFocusable 组件库
- 实现 Focus 导航策略
- 改造 MainLayout 导航栏
- 改造所有列表/网格组件

### Phase 3: 播放器适配（2-3天）
- 实现 video_player 适配器
- 创建 TVPlayerControls
- 适配 PlayerScreen 布局
- 实现 tvOS PiP（AVFoundation）

### Phase 4: 页面适配（2-3天）
- 改造 HomeScreen
- 改造 SearchScreen
- 改造 LiveScreen/LivePlayerScreen
- 改造 LoginScreen
- 添加 tvTheme

### Phase 5: 验证与发布（1-2天）
- 10-foot UI 合规检查
- Apple TV 模拟器/真机测试
- App Store 截图和元数据
- 归档和提交

## 验证方式

1. **模拟器测试**：`flutter build ios --platform=tvos` 构建后在 tvOS 模拟器运行
2. **Focus 遍历测试**：用方向键遍历所有屏幕，确保无死锁
3. **播放测试**：测试 MP4/HLS 多种视频源播放
4. **真机测试**：Apple TV 4K 真机性能测试