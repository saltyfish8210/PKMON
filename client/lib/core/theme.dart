import 'package:flutter/material.dart';

import 'tokens.dart';

/// 组装全局 ThemeData。
///
/// 页面里尽量少写样式，能靠主题统一掉的（文字颜色、页面底色）在这里定，
/// 页面只负责布局。
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansSC',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.page,
  );

  return base.copyWith(
    // 中文环境下默认字重偏细，标题类文字在各页面单独指定字重。
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}
