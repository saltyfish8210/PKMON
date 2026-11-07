import 'package:flutter/material.dart';

import '../../widgets/loading_view.dart';
import '../home_shell.dart';
import '../member_home_page.dart';
import 'auth_controller.dart';
import 'login_page.dart';
import 'session_store.dart';
import '../../core/api.dart';
import '../../data/api/api_client.dart';
import '../../data/api/auth_api.dart';
import 'session_token_provider.dart';

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
  ApiClient? _client;
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    if (_ownsController) {
      final store = InMemorySessionStore();
      _client = ApiClient(
        baseUrl: Uri.parse(Api.defaultBase),
        tokens: SessionTokenProvider(store),
        onUnauthorized: () {
          if (_controller.status == AuthStatus.signedIn) {
            _controller.handleUnauthorized();
          }
        },
      );
      _controller = AuthController(api: HttpAuthApi(_client!), store: store);
    } else {
      _controller = widget.controller!;
    }
    _controller.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.status == AuthStatus.unknown) {
        _controller.restore();
      }
    });
  }

  void _onChanged() {
    if (!mounted) return;
    if (_wasSignedIn && _controller.status == AuthStatus.signedOut) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _wasSignedIn = _controller.status == AuthStatus.signedIn;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    _client?.close();
    super.dispose();
  }

  Widget _home(BuildContext context) {
    if (widget.homeBuilder != null) return widget.homeBuilder!(context);
    if (_controller.status == AuthStatus.signedIn && _client != null) {
      return MemberHomePage(
        client: _client!,
        nickname: _controller.session!.user.nickname,
        onLogout: _controller.logout,
      );
    }
    return const HomeShell();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_controller.status) {
      AuthStatus.unknown || AuthStatus.restoring => const Scaffold(
        body: LoadingView(message: '正在恢复登录状态…'),
      ),
      AuthStatus.signedIn => _home(context),
      AuthStatus.signedOut =>
        _demo
            ? _home(context)
            : LoginPage(
                controller: _controller,
                onEnterDemo: () => setState(() => _demo = true),
              ),
    };
  }
}
