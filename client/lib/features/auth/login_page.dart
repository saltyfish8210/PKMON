import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/error_view.dart';
import 'auth_controller.dart';

/// 登录页骨架。
///
/// 只负责输入、基础校验和状态显示；真实账号接口尚未接入，
/// 因此登录会得到明确的「未接入」错误，不会伪造成功。
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.controller,
    required this.onEnterDemo,
  });

  final AuthController controller;
  final VoidCallback onEnterDemo;

  static const String skeletonNotice =
      '账号接口未接入（骨架）。真实登录/注册暂不可用；本页不会伪造登录成功。';
  static const String registerNotice =
      '注册页待接入（下一阶段）；注册接口契约已在设计中定义。';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text;
    final password = _password.text;

    if (username.trim().isEmpty) {
      setState(() => _localError = '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      setState(() => _localError = '请输入密码');
      return;
    }

    setState(() => _localError = null);
    await widget.controller.login(username, password);
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.listCard),
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
                        label: busy ? '登录中…' : '登录',
                        onPressed: busy ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.base * 3),
                      SecondaryButton(
                        key: const Key('login_demo'),
                        label: '进入演示（不登录）',
                        onPressed: busy ? null : widget.onEnterDemo,
                      ),
                      const SizedBox(height: AppSpacing.base * 6),
                      const Text(
                        LoginPage.registerNotice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFontSizes.secondary,
                          color: AppColors.secondaryText,
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
