import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 统一的错误态。
///
/// [onRetry] 为空时只显示错误说明，不出现无效的「重试」按钮。
/// [compact] 用于嵌在表单里的小块提示，不占满整屏。
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = '重试',
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.errorText, size: 20),
        const SizedBox(width: AppSpacing.base * 2),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.errorText,
            ),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: AppSpacing.base * 2),
          TextButton(
            onPressed: onRetry,
            child: Text(
              retryLabel,
              style: const TextStyle(color: AppColors.errorText),
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.base * 3),
        decoration: BoxDecoration(
          color: AppColors.errorSurface,
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: content,
      ),
    );
  }
}
