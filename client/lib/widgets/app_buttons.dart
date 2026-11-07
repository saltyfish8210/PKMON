import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 主按钮：满宽、实心主色、圆角 12、最小高 50。
///
/// 设计稿里地图页的「模拟走到图书馆」、抓捕页的「返回地图」都是它。
///
/// `onPressed` 传 null 就是禁用态（变灰、点不动）——注意这里**不能**写
/// `onPressed ?? () {}`，那样传 null 会被替换成空函数，按钮看着是灰的却仍然响应点击。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;

  /// 左侧图标，可不传
  final IconData? icon;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: AppFontSizes.body,
        fontWeight: FontWeight.w600,
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonMinHeight,
      child: icon == null
          ? FilledButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
    );
  }
}

/// 次按钮：白底 + 描边，用于个人页的「重新开始演示」。
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: AppFontSizes.body,
        fontWeight: FontWeight.w600,
      ),
    );

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonMinHeight,
      child: icon == null
          ? OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
    );
  }
}
