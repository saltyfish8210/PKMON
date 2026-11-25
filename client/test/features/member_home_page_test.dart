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
        final path = request.url.path;
        paths.add(path);
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (path.endsWith('/collection/dex')) {
          return envelope({
            'collectedSpeciesCount': captures > 0 ? 1 : 0,
            'totalSpeciesCount': 1,
            'entries': [
              {
                'speciesId': 'siege_lion',
                'name': '攻城狮',
                'count': captures,
                'firstCapturedAt': captures > 0 ? '2026-11-16T02:00:00Z' : null,
              },
            ],
          });
        }
        if (path.endsWith('/collection/bag')) {
          return envelope({
            'totalCount': captures,
            'speciesCount': captures > 0 ? 1 : 0,
            'entries': captures > 0
                ? [
                    {
                      'speciesId': 'siege_lion',
                      'name': '攻城狮',
                      'count': captures,
                      'latestCapturedAt': '2026-11-16T02:00:00Z',
                    },
                  ]
                : <Map<String, dynamic>>[],
          });
        }
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
    const summary = '/api/v1/collection/summary';
    expect(paths, [summary]);
    paths.clear();
    await tester.ensureVisible(find.text('查看收藏'));
    await tester.tap(find.text('查看收藏'));
    await tester.pumpAndSettle();
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.text('图鉴'), findsOneWidget);
    expect(find.text('未解锁'), findsOneWidget);
    expect(paths, unorderedEquals([summary, '/api/v1/collection/dex', '/api/v1/collection/bag']));
    paths.clear();
    captures = 1;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('已收集 1 / 1 种 · 累计捕获 1 次'), findsOneWidget);
    expect(paths, [summary]);
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
