import 'package:flutter/material.dart';

import '../../widgets/loading_view.dart';
import '../home_shell.dart';
import 'auth_controller.dart';
import 'login_page.dart';
import 'session_store.dart';
import 'unavailable_auth_api.dart';

/// 入口门禁。
///
/// 冷启动先恢复本地会话：
/// - 无会话或已过期 → 登录页；
/// - 有有效会话 → 主界面；
/// - 「进入演示」只切换本地标志，不创建、不保存 Session。
///
/// 业务页面不依赖本类；只有入口负责接线。
class AppGate extends StatefulWidget {
  const AppGate({super.key, this.controller, this.homeBuilder});

  /// 测试可注入已配置的控制器；为空时使用骨架默认实现。
  final AuthController? controller;

  /// 测试可注入替身首页，避免触发真实页面里的网络请求。
  final WidgetBuilder? homeBuilder;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  late final AuthController _controller;
  late final bool _ownsController;
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AuthController(
          api: const UnavailableAuthApi(),
          store: InMemorySessionStore(),
        );
    _controller.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.status == AuthStatus.unknown) {
        _controller.restore();
      }
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Widget _home(BuildContext context) {
    return widget.homeBuilder?.call(context) ?? const HomeShell();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_controller.status) {
      AuthStatus.unknown || AuthStatus.restoring =>
        const Scaffold(body: LoadingView(message: '正在恢复登录状态…')),
      AuthStatus.signedIn => _home(context),
      AuthStatus.signedOut => _demo
          ? _home(context)
          : LoginPage(
              controller: _controller,
              onEnterDemo: () => setState(() => _demo = true),
            ),
    };
  }
}
