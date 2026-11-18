import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// 网页版「手机壳」：把界面收进一个手机大小的框里居中显示。
///
/// **只在网页版生效。** 安卓上它直接就返回原样，全屏铺满——
/// 手机上本来就是手机屏幕，再套一层壳没意义。
///
/// 窗口本来就窄的时候（比如真的用手机浏览器打开网页）也不加壳，
/// 铺满更好用。
///
/// 为什么要包在 `MaterialApp.builder` 里而不是某个页面里：
/// `builder` 包住的是整个 Navigator，所以**所有路由**（主页、答题页…）
/// 都在壳里，不用每个页面各写一遍，将来加新页面也自动生效。
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 安卓/桌面端：原样返回，不做任何处理
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 展示/投影场景：窗口够宽时铺满，但收在居中的一列里，
        // 免得表格与列表被拉成横跨整屏的一条。
        if (constraints.maxWidth >= AppSpacing.webFullBleedBreakpoint) {
          return ColoredBox(
            color: AppColors.webBackdrop,
            child: Center(
              child: SizedBox(
                width: AppSpacing.webContentWidth,
                height: constraints.maxHeight,
                child: child,
              ),
            ),
          );
        }
        // 窗口不够宽，说明本来就是小屏，不用加壳
        if (constraints.maxWidth <= AppSpacing.phonePreviewBreakpoint) {
          return child;
        }

        return ColoredBox(
          color: AppColors.webBackdrop,
          child: Center(
            child: SizedBox(
              width: AppSpacing.phonePreviewWidth,
              // 高度撑满，只限制宽度——和旧版的行为一致
              height: constraints.maxHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
