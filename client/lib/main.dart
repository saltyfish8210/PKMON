import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'core/theme.dart';
import 'features/auth/app_gate.dart';
import 'widgets/phone_frame.dart';

/// App 入口。
///
/// `main()` 只做一件事：把根组件挂到屏幕上。
/// 具体长什么样由 [PkmonApp] 决定；入口先经过 [AppGate] 的登录门禁。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 提前打开无障碍语义树。地图上那个精灵挂了 Semantics 标签
  // （读屏会念「遇见攻城狮」），不开这个开关标签不会生效。
  SemanticsBinding.instance.ensureSemantics();
  runApp(const PkmonApp());
}

class PkmonApp extends StatelessWidget {
  const PkmonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PKMon',
      // 关掉右上角那个 DEBUG 角标
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppGate(),

      // 用 builder 而不是在某个页面里包一层：builder 包住的是整个
      // Navigator，所以所有页面都在「手机壳」里，不用每页各写一遍。
      // 详见 [PhoneFrame]（安卓上它是透明的，不影响全屏显示）。
      builder: (context, child) =>
          PhoneFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
