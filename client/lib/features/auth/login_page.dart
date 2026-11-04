import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/error_view.dart';
import 'auth_controller.dart';
import 'auth_input.dart';

/// 登录页骨架。
///
/// 账号请求由入口注入的控制器处理。
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.controller,
    required this.onEnterDemo,
  });

  final AuthController controller;
  final VoidCallback onEnterDemo;

  static const String skeletonNotice = '登录后可开始自习并保存本次会话。';
  static const String registerNotice = '注册新账号';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _localError;
  bool _registering = false;
  final _nickname = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text;
    final password = _password.text;

    final inputError = _registering
        ? validateRegisterInput(username, password, _nickname.text)
        : validateLoginInput(username, password);
    if (inputError != null) {
      setState(() => _localError = inputError);
      return;
    }

    setState(() => _localError = null);
    if (_registering) {
      final result = await widget.controller.register(
        username,
        password,
        _nickname.text,
      );
      if (result != null && mounted) setState(() => _registering = false);
    } else {
      await widget.controller.login(username, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final busy = widget.controller.busy;
            final error = _localError ?? widget.controller.error;
            final notice = widget.controller.notice;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.captureSide,
                vertical: AppSpacing.base * 8,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '登录 PKMon',
                        style: TextStyle(
                          fontSize: AppFontSizes.pageTitle,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base * 2),
                      const Text(
                        '用校园账号同步你的图鉴与收藏。',
                        style: TextStyle(
                          fontSize: AppFontSizes.body,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base * 6),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.base * 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(
                            AppRadius.listCard,
                          ),
                        ),
                        child: const Text(
                          LoginPage.skeletonNotice,
                          style: TextStyle(
                            fontSize: AppFontSizes.secondary,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base * 6),
                      TextField(
                        key: const Key('login_username'),
                        controller: _username,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          hintText: '不超过 24 个字符',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base * 4),
                      if (_registering)
                        TextField(
                          controller: _nickname,
                          enabled: !busy,
                          decoration: const InputDecoration(labelText: '昵称'),
                        ),
                      TextField(
                        key: const Key('login_password'),
                        controller: _password,
                        enabled: !busy,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: busy ? null : (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: '密码',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: AppSpacing.base * 4),
                        ErrorView(message: error, compact: true),
                      ],
                      if (notice != null) ...[
                        const SizedBox(height: AppSpacing.base * 4),
                        Text(
                          notice,
                          style: const TextStyle(
                            fontSize: AppFontSizes.body,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.base * 6),
                      PrimaryButton(
                        key: const Key('login_submit'),
                        label: busy
                            ? (_registering ? '注册中…' : '登录中…')
                            : _registering
                            ? '创建账号'
                            : '登录',
                        onPressed: busy ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.base * 3),
                      SecondaryButton(
                        key: const Key('login_demo'),
                        label: '进入演示（不登录）',
                        onPressed: busy ? null : widget.onEnterDemo,
                      ),
                      const SizedBox(height: AppSpacing.base * 6),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                widget.controller.clearError();
                                setState(() {
                                  _registering = !_registering;
                                  _localError = null;
                                });
                              },
                        child: Text(
                          _registering ? '返回登录' : LoginPage.registerNotice,
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
    );
  }
}
