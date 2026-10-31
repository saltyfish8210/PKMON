import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/widgets/empty_view.dart';
import 'package:pkmon_app/widgets/error_view.dart';
import 'package:pkmon_app/widgets/loading_view.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('加载态显示进度与说明', (tester) async {
    await tester.pumpWidget(wrap(const LoadingView(message: '正在恢复登录状态…')));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在恢复登录状态…'), findsOneWidget);
  });

  testWidgets('错误态显示说明并可重试', (tester) async {
    var retried = 0;
    await tester.pumpWidget(wrap(ErrorView(
      message: '网络异常',
      onRetry: () => retried++,
    )));

    expect(find.text('网络异常'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, 1);
  });

  testWidgets('错误态没有回调时不显示无效按钮', (tester) async {
    await tester.pumpWidget(wrap(const ErrorView(message: '网络异常')));

    expect(find.text('网络异常'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('空态显示标题、说明和动作', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(EmptyView(
      title: '还没有记录',
      message: '完成一次相遇后再来看看。',
      actionLabel: '回到地图',
      onAction: () => tapped++,
    )));

    expect(find.text('还没有记录'), findsOneWidget);
    expect(find.text('完成一次相遇后再来看看。'), findsOneWidget);
    await tester.tap(find.text('回到地图'));
    expect(tapped, 1);
  });
}
