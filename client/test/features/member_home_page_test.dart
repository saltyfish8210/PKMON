import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pkmon_app/features/member_home_page.dart';

import '../data/test_support.dart';

void main() {
  testWidgets('账号首页及收藏只读取正式接口，返回时刷新数量', (tester) async {
    var captures = 0;
    final paths = <String>[];
    final client = clientWith(
      MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer test-token');
        return envelope({
          'collectedSpeciesCount': captures > 0 ? 1 : 0,
          'totalSpeciesCount': 1,
          'captureCount': captures,
        });
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHomePage(
          client: client,
          nickname: '同学',
          onLogout: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已收集 0 / 1 种 · 累计捕获 0 次'), findsOneWidget);
    await tester.ensureVisible(find.text('查看收藏'));
    await tester.tap(find.text('查看收藏'));
    await tester.pumpAndSettle();
    expect(find.text('收藏概览'), findsOneWidget);
    captures = 1;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('已收集 1 / 1 种 · 累计捕获 1 次'), findsOneWidget);
    expect(paths.length, 3);
    expect(paths.every((path) => path == '/api/v1/collection/summary'), isTrue);
  });

  testWidgets('加载失败可以重试，退出登录调用账号退出', (tester) async {
    var failed = true;
    var loggedOut = false;
    final client = clientWith(
      MockClient(
        (_) async => failed
            ? jsonResponse({
                'code': 50000,
                'message': '服务暂不可用',
                'data': null,
              }, status: 500)
            : envelope({
                'collectedSpeciesCount': 1,
                'totalSpeciesCount': 1,
                'captureCount': 2,
              }),
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHomePage(
          client: client,
          nickname: '同学',
          onLogout: () async {
            loggedOut = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    failed = false;
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('已收集 1 / 1 种 · 累计捕获 2 次'), findsOneWidget);
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });
}
