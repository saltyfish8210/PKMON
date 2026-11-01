import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 统一的加载态。
///
/// 只负责显示，不判断登录、权限或业务规则。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = '正在加载…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSpacing.base * 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
