import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../core/platform_detector.dart';
import '../services/user_data_service.dart';
import '../services/local_mode_storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';
import '../widgets/windows_title_bar.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/custom_switch.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _subscriptionUrlController = TextEditingController();
  bool _isPasswordVisible = false;

  // tvOS Focus 导航节点（外层高亮包裹，内层为文本输入）
  final _urlTvNode = FocusNode(debugLabel: 'url_tv');
  final _usernameTvNode = FocusNode(debugLabel: 'username_tv');
  final _passwordTvNode = FocusNode(debugLabel: 'password_tv');
  final _loginButtonTvNode = FocusNode(debugLabel: 'login_button_tv');
  final _localModeTvNode = FocusNode(debugLabel: 'local_mode_tv');
  final _subscriptionUrlTvNode = FocusNode(debugLabel: 'subscription_url_tv');
  final _urlFieldNode = FocusNode(debugLabel: 'url_field');
  final _usernameFieldNode = FocusNode(debugLabel: 'username_field');
  final _passwordFieldNode = FocusNode(debugLabel: 'password_field');
  final _subscriptionUrlFieldNode = FocusNode(debugLabel: 'subscription_url_field');
  bool _isLoading = false;
  bool _isFormValid = false;
  bool _isLocalMode = false;

  // 点击计数器相关
  int _logoTapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_validateForm);
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _subscriptionUrlController.addListener(_validateForm);
    _loadSavedUserData();
  }

  void _loadSavedUserData() async {
    final userData = await UserDataService.getAllUserData();
    if (!mounted) return;

    bool hasData = false;

    if (userData['serverUrl'] != null) {
      _urlController.text = userData['serverUrl']!;
      hasData = true;
    }
    if (userData['username'] != null) {
      _usernameController.text = userData['username']!;
      hasData = true;
    }
    if (userData['password'] != null) {
      _passwordController.text = userData['password']!;
      hasData = true;
    }

    // 加载订阅链接（用于回填）
    final subscriptionUrl = await LocalModeStorageService.getSubscriptionUrl();
    if (!mounted) return;

    if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
      _subscriptionUrlController.text = subscriptionUrl;
      hasData = true;
    }

    // 如果有数据被加载，更新UI状态
    if (hasData && mounted) {
      _validateForm();
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _subscriptionUrlController.dispose();
    // tvOS Focus 节点
    _urlTvNode.dispose();
    _usernameTvNode.dispose();
    _passwordTvNode.dispose();
    _loginButtonTvNode.dispose();
    _localModeTvNode.dispose();
    _subscriptionUrlTvNode.dispose();
    _urlFieldNode.dispose();
    _usernameFieldNode.dispose();
    _passwordFieldNode.dispose();
    _subscriptionUrlFieldNode.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleLogoTap() {
    _logoTapCount++;

    // 取消之前的计时器
    _tapTimer?.cancel();

    // 如果达到10次，切换到本地模式
    if (_logoTapCount >= 10) {
      setState(() {
        _isLocalMode = !_isLocalMode;
        _validateForm();
        _logoTapCount = 0;
      });
      _showToast(
        _isLocalMode ? '已切换到本地模式' : '已切换到服务器模式',
        const Color(0xFF27ae60),
      );
    } else {
      // 设置新的计时器，2秒后重置计数
      _tapTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _logoTapCount = 0;
        });
      });
    }
  }

  // tvOS 本地模式开关切换
  void _toggleLocalMode() {
    setState(() {
      _isLocalMode = !_isLocalMode;
      _validateForm();
    });
    _showToast(
      _isLocalMode ? '已切换到本地模式' : '已切换到服务器模式',
      const Color(0xFF27ae60),
    );
  }

  void _validateForm() {
    if (!mounted) return;

    setState(() {
      if (_isLocalMode) {
        _isFormValid = _subscriptionUrlController.text.isNotEmpty;
      } else {
        _isFormValid = _urlController.text.isNotEmpty &&
            _usernameController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty;
      }
    });
  }

  // 处理回车键提交
  void _handleSubmit() {
    if (_isLocalMode) {
      _handleLocalModeLogin();
    } else {
      _handleLogin();
    }
  }

  Widget _buildLocalModeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 订阅链接输入框
        TextFormField(
          controller: _subscriptionUrlController,
          style: FontUtils.poppins(
            fontSize: 16,
            color: const Color(0xFF2c3e50),
          ),
          decoration: InputDecoration(
            labelText: '订阅链接',
            labelStyle: FontUtils.poppins(
              color: const Color(0xFF7f8c8d),
              fontSize: 14,
            ),
            hintText: '请输入订阅链接',
            hintStyle: FontUtils.poppins(
              color: const Color(0xFFbdc3c7),
              fontSize: 16,
            ),
            prefixIcon: const Icon(
              Icons.link,
              color: Color(0xFF7f8c8d),
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入订阅链接';
            }
            return null;
          },
          onChanged: (value) => _validateForm(),
          onFieldSubmitted: (_) => _handleSubmit(),
        ),
        const SizedBox(height: 32),

        // 登录按钮
        ElevatedButton(
          onPressed:
              (_isLoading || !_isFormValid) ? null : _handleLocalModeLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid && !_isLoading
                ? const Color(0xFF2c3e50)
                : const Color(0xFFbdc3c7),
            foregroundColor: _isFormValid && !_isLoading
                ? Colors.white
                : const Color(0xFF7f8c8d),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '登录中...',
                      style: FontUtils.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  '登录',
                  style: FontUtils.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ],
    );
  }

  String _processUrl(String url) {
    // 去除尾部斜杠
    String processedUrl = url.trim();
    if (processedUrl.endsWith('/')) {
      processedUrl = processedUrl.substring(0, processedUrl.length - 1);
    }
    return processedUrl;
  }

  String _parseCookies(http.Response response) {
    // 解析 Set-Cookie 头部
    List<String> cookies = [];

    // 获取所有 Set-Cookie 头部
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      // HTTP 头部通常是 String 类型
      final cookieParts = setCookieHeaders.split(';');
      if (cookieParts.isNotEmpty) {
        cookies.add(cookieParts[0].trim());
      }
    }

    return cookies.join('; ');
  }

  void _showToast(String message, Color backgroundColor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: FontUtils.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate() && _isFormValid) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 处理 URL
        String baseUrl = _processUrl(_urlController.text);
        String loginUrl = '$baseUrl/api/login';

        // 发送登录请求
        final response = await http.post(
          Uri.parse(loginUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'username': _usernameController.text,
            'password': _passwordController.text,
          }),
        );
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // 根据状态码显示不同的消息
        switch (response.statusCode) {
          case 200:
            // 解析并保存 cookies
            String cookies = _parseCookies(response);

            // 保存用户数据
            await UserDataService.saveUserData(
              serverUrl: baseUrl,
              username: _usernameController.text,
              password: _passwordController.text,
              cookies: cookies,
            );
            if (!mounted) return;

            // 保存模式状态为服务器模式
            await UserDataService.saveIsLocalMode(false);
            if (!mounted) return;

            // _showToast('登录成功！', const Color(0xFF27ae60));

            // 跳转到首页，并清除所有路由栈（强制销毁所有旧页面）
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
            break;
          case 401:
            _showToast('用户名或密码错误', const Color(0xFFe74c3c));
            break;
          case 500:
            _showToast('服务器错误', const Color(0xFFe74c3c));
            break;
          default:
            _showToast('网络异常', const Color(0xFFe74c3c));
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showToast('网络异常', const Color(0xFFe74c3c));
      }
    }
  }

  void _handleLocalModeLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newUrl = _subscriptionUrlController.text.trim();

        // 获取并解析订阅内容
        final response = await http.get(Uri.parse(newUrl));
        if (!mounted) return;

        if (response.statusCode != 200) {
          setState(() {
            _isLoading = false;
          });
          _showToast('获取订阅内容失败', const Color(0xFFe74c3c));
          return;
        }

        final content =
            await SubscriptionService.parseSubscriptionContent(response.body);
        if (!mounted) return;

        if (content == null || 
            (content.searchResources == null || content.searchResources!.isEmpty) &&
            (content.liveSources == null || content.liveSources!.isEmpty)) {
          setState(() {
            _isLoading = false;
          });
          _showToast('解析订阅内容失败', const Color(0xFFe74c3c));
          return;
        }

        // 检查是否已有订阅 URL
        final existingUrl = await LocalModeStorageService.getSubscriptionUrl();
        if (!mounted) return;

        if (existingUrl != null &&
            existingUrl.isNotEmpty &&
            existingUrl != newUrl) {
          // 弹窗询问是否清空
          setState(() {
            _isLoading = false;
          });

          if (!mounted) return;

          final shouldClear = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                '提示',
                style: FontUtils.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2c3e50),
                ),
              ),
              content: Text(
                '检测到已有本地模式内容且订阅链接不一致，是否清空全部本地模式存储？',
                style: FontUtils.poppins(
                  fontSize: 14,
                  color: const Color(0xFF2c3e50),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    '否',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFF7f8c8d),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    '是',
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFFe74c3c),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (!mounted) return;

          if (shouldClear == true) {
            await LocalModeStorageService.clearAllLocalModeData();
            if (!mounted) return;
          } else if (shouldClear == null) {
            // 用户取消了对话框
            return;
          }

          setState(() {
            _isLoading = true;
          });
        }

        // 保存订阅链接和内容
        await LocalModeStorageService.saveSubscriptionUrl(newUrl);
        if (!mounted) return;
        if (content.searchResources != null && content.searchResources!.isNotEmpty) {
          await LocalModeStorageService.saveSearchSources(content.searchResources!);
          if (!mounted) return;
        }
        if (content.liveSources != null && content.liveSources!.isNotEmpty) {
          await LocalModeStorageService.saveLiveSources(content.liveSources!);
          if (!mounted) return;
        }

        // 保存模式状态为本地模式
        await UserDataService.saveIsLocalMode(true);
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // _showToast('本地模式登录成功！', const Color(0xFF27ae60));

        // 跳转到首页，并清除所有路由栈（强制销毁所有旧页面）
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showToast('登录失败：${e.toString()}', const Color(0xFFe74c3c));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // tvOS 专用 10-foot UI 布局（Focus 表单导航 + 大字体暗色主题）
    if (PlatformDetector.isTVOS) {
      return _buildTVLayout();
    }

    final isTablet = DeviceUtils.isTablet(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFe6f3fb), // #e6f3fb 0%
              Color(0xFFeaf3f7), // #eaf3f7 18%
              Color(0xFFf7f7f3), // #f7f7f3 38%
              Color(0xFFe9ecef), // #e9ecef 60%
              Color(0xFFdbe3ea), // #dbe3ea 80%
              Color(0xFFd3dde6), // #d3dde6 100%
            ],
            stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Windows 自定义标题栏（透明背景）
            if (PlatformDetector.isWindows) const WindowsTitleBar(forceBlack: true),
            // 主要内容
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 0 : 32.0,
                      vertical: 24.0,
                    ),
                    child:
                        isTablet ? _buildTabletLayout() : _buildMobileLayout(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 手机端布局（保持原样）
  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Selene 标题 - 可点击
        GestureDetector(
          onTap: _handleLogoTap,
          child: Text(
            'Selene',
            style: FontUtils.sourceCodePro(
              fontSize: 42,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF2c3e50),
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 40),

        // 登录表单 - 无边框设计
        Form(
          key: _formKey,
          child: _isLocalMode
              ? _buildLocalModeForm()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // URL 输入框
                    TextFormField(
                      controller: _urlController,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2c3e50),
                      ),
                      decoration: InputDecoration(
                        labelText: '服务器地址',
                        labelStyle: FontUtils.poppins(
                          color: const Color(0xFF7f8c8d),
                          fontSize: 14,
                        ),
                        hintText: 'https://example.com',
                        hintStyle: FontUtils.poppins(
                          color: const Color(0xFFbdc3c7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.link,
                          color: Color(0xFF7f8c8d),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入服务器地址';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            uri.scheme.isEmpty ||
                            uri.host.isEmpty) {
                          return '请输入有效的URL地址';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 20),

                    // 用户名输入框
                    TextFormField(
                      controller: _usernameController,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2c3e50),
                      ),
                      decoration: InputDecoration(
                        labelText: '用户名',
                        labelStyle: FontUtils.poppins(
                          color: const Color(0xFF7f8c8d),
                          fontSize: 14,
                        ),
                        hintText: '请输入用户名',
                        hintStyle: FontUtils.poppins(
                          color: const Color(0xFFbdc3c7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Color(0xFF7f8c8d),
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入用户名';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 20),

                    // 密码输入框
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: FontUtils.poppins(
                        fontSize: 16,
                        color: const Color(0xFF2c3e50),
                      ),
                      decoration: InputDecoration(
                        labelText: '密码',
                        labelStyle: FontUtils.poppins(
                          color: const Color(0xFF7f8c8d),
                          fontSize: 14,
                        ),
                        hintText: '请输入密码',
                        hintStyle: FontUtils.poppins(
                          color: const Color(0xFFbdc3c7),
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Color(0xFF7f8c8d),
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: const Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 32),

                    // 登录按钮
                    ElevatedButton(
                      onPressed:
                          (_isLoading || !_isFormValid) ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFormValid && !_isLoading
                            ? const Color(0xFF2c3e50) // 与Selene logo相同的颜色
                            : const Color(0xFFbdc3c7), // 禁用时的浅灰色
                        foregroundColor: _isFormValid && !_isLoading
                            ? Colors.white
                            : const Color(0xFF7f8c8d), // 禁用时的文字颜色
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '登录中...',
                                  style: FontUtils.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '登录',
                              style: FontUtils.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // 平板端布局（与手机端风格一致，只是限制宽度）
  Widget _buildTabletLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selene 标题 - 可点击
          GestureDetector(
            onTap: _handleLogoTap,
            child: Text(
              'Selene',
              style: FontUtils.sourceCodePro(
                fontSize: 42,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF2c3e50),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // 登录表单 - 无边框设计
          Form(
            key: _formKey,
            child: _isLocalMode
                ? _buildLocalModeForm()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // URL 输入框
                      TextFormField(
                        controller: _urlController,
                        style: FontUtils.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2c3e50),
                        ),
                        decoration: InputDecoration(
                          labelText: '服务器地址',
                          labelStyle: FontUtils.poppins(
                            color: const Color(0xFF7f8c8d),
                            fontSize: 14,
                          ),
                          hintText: 'https://example.com',
                          hintStyle: FontUtils.poppins(
                            color: const Color(0xFFbdc3c7),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.link,
                            color: Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入服务器地址';
                          }
                          final uri = Uri.tryParse(value);
                          if (uri == null ||
                              uri.scheme.isEmpty ||
                              uri.host.isEmpty) {
                            return '请输入有效的URL地址';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 20),

                      // 用户名输入框
                      TextFormField(
                        controller: _usernameController,
                        style: FontUtils.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2c3e50),
                        ),
                        decoration: InputDecoration(
                          labelText: '用户名',
                          labelStyle: FontUtils.poppins(
                            color: const Color(0xFF7f8c8d),
                            fontSize: 14,
                          ),
                          hintText: '请输入用户名',
                          hintStyle: FontUtils.poppins(
                            color: const Color(0xFFbdc3c7),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入用户名';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 20),

                      // 密码输入框
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: FontUtils.poppins(
                          fontSize: 16,
                          color: const Color(0xFF2c3e50),
                        ),
                        decoration: InputDecoration(
                          labelText: '密码',
                          labelStyle: FontUtils.poppins(
                            color: const Color(0xFF7f8c8d),
                            fontSize: 14,
                          ),
                          hintText: '请输入密码',
                          hintStyle: FontUtils.poppins(
                            color: const Color(0xFFbdc3c7),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFF7f8c8d),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF7f8c8d),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.6),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入密码';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 32),

                      // 登录按钮
                      ElevatedButton(
                        onPressed:
                            (_isLoading || !_isFormValid) ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFormValid && !_isLoading
                              ? const Color(0xFF2c3e50)
                              : const Color(0xFFbdc3c7),
                          foregroundColor: _isFormValid && !_isLoading
                              ? Colors.white
                              : const Color(0xFF7f8c8d),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '登录中...',
                                    style: FontUtils.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '登录',
                                style: FontUtils.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---- tvOS 专用布局（10-foot UI）----

  Widget _buildTVLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: FocusTraversalGroup(
            policy: _LoginFocusTraversal([
              _urlTvNode,
              _usernameTvNode,
              _passwordTvNode,
              _loginButtonTvNode,
              _localModeTvNode,
              _subscriptionUrlTvNode,
            ]),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selene 标题
                    const Text(
                      'Selene',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 56),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Focus 顺序：服务器 URL → 用户名 → 密码
                          _buildTVTextField(
                            tvNode: _urlTvNode,
                            fieldNode: _urlFieldNode,
                            controller: _urlController,
                            label: '服务器地址',
                            hint: 'https://example.com',
                            icon: Icons.link,
                            autofocus: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入服务器地址';
                              }
                              final uri = Uri.tryParse(value);
                              if (uri == null ||
                                  uri.scheme.isEmpty ||
                                  uri.host.isEmpty) {
                                return '请输入有效的URL地址';
                              }
                              return null;
                            },
                          ),
                          _buildTVTextField(
                            tvNode: _usernameTvNode,
                            fieldNode: _usernameFieldNode,
                            controller: _usernameController,
                            label: '用户名',
                            hint: '请输入用户名',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入用户名';
                              }
                              return null;
                            },
                          ),
                          _buildTVTextField(
                            tvNode: _passwordTvNode,
                            fieldNode: _passwordFieldNode,
                            controller: _passwordController,
                            label: '密码',
                            hint: '请输入密码',
                            icon: Icons.lock,
                            obscure: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入密码';
                              }
                              return null;
                            },
                          ),

                          // 登录按钮
                          _buildTVLoginButton(),

                          // 本地模式开关
                          _buildTVLocalModeSwitch(),

                          // 本地模式下的订阅 URL
                          if (_isLocalMode)
                            _buildTVTextField(
                              tvNode: _subscriptionUrlTvNode,
                              fieldNode: _subscriptionUrlFieldNode,
                              controller: _subscriptionUrlController,
                              label: '订阅链接',
                              hint: '请输入订阅链接',
                              icon: Icons.link,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入订阅链接';
                                }
                                return null;
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTVTextField({
    required FocusNode tvNode,
    required FocusNode fieldNode,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool autofocus = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: TVFocusableWidget(
        focusNode: tvNode,
        autofocus: autofocus,
        onTap: () => FocusScope.of(context).requestFocus(fieldNode),
        child: TextFormField(
          controller: controller,
          focusNode: fieldNode,
          obscureText: obscure,
          style: const TextStyle(fontSize: 22, color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70, fontSize: 20),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 20),
            prefixIcon: Icon(icon, color: Colors.white70, size: 28),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 22,
            ),
          ),
          validator: validator,
          onChanged: (_) => _validateForm(),
          onFieldSubmitted: (_) => _handleSubmit(),
        ),
      ),
    );
  }

  Widget _buildTVLoginButton() {
    final enabled = _isFormValid && !_isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: TVFocusableWidget(
        focusNode: _loginButtonTvNode,
        onTap: enabled ? _handleSubmit : null,
        child: ElevatedButton(
          onPressed: enabled ? _handleSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2c3e50),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF333333),
            disabledForegroundColor: Colors.white38,
            padding: const EdgeInsets.symmetric(vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: _isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      '登录中...',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : const Text(
                  '登录',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTVLocalModeSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TVFocusableWidget(
        focusNode: _localModeTvNode,
        onTap: _toggleLocalMode,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.language, color: Colors.white70, size: 32),
            const SizedBox(width: 14),
            const Text(
              '本地模式',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            const SizedBox(width: 16),
            CustomSwitch(
              value: _isLocalMode,
              onChanged: (_) => _toggleLocalMode(),
              activeColor: const Color(0xFF27ae60),
              inactiveColor: const Color(0xFF555555),
              width: 72,
              height: 40,
            ),
          ],
        ),
      ),
    );
  }
}

/// tvOS 登录表单纵向 Focus 导航策略
/// 仅遍历外层 TVFocusableWidget 节点（排除 TextFormField 内部输入节点），
/// 按从上到下的视觉顺序导航，确保方向键上下在字段间移动。
class _LoginFocusTraversal extends FocusTraversalPolicy {
  final List<FocusNode> primaryNodes;

  _LoginFocusTraversal(this.primaryNodes);

  Iterable<FocusNode> _filtered(Iterable<FocusNode> descendants) =>
      descendants.where(primaryNodes.contains);

  Rect _rect(FocusNode node) {
    final renderBox = node.context?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Rect.zero;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants, {
    FocusNode? currentNode,
  }) {
    final sorted = _filtered(descendants).toList()
      ..sort((a, b) {
        final aRect = _rect(a);
        final bRect = _rect(b);
        final cmp = aRect.top.compareTo(bRect.top);
        return cmp != 0 ? cmp : aRect.left.compareTo(bRect.left);
      });
    return sorted;
  }
}
