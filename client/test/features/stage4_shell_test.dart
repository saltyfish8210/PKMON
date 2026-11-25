import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pkmon_app/features/home_shell.dart';
import '../data/test_support.dart';

void main() {
  testWidgets('同一账号四页使用同一批真实响应，未触发演示请求', (tester) async {
    final paths = <String>[];
    final client = clientWith(MockClient((request) async {
      final key = request.url.pathSegments.last;
      paths.add(key);
      expect(request.headers['Authorization'], 'Bearer test-token');
      final example = File('../docs/stage4/examples/$key.json');
      return jsonResponse(jsonDecode(example.readAsStringSync()));
    }));
    addTearDown(client.close);
    await tester.pumpWidget(MaterialApp(home: HomeShell(accountClient: client, nickname: '验收')));
    await tester.pumpAndSettle();
    expect(find.text('收集 1 / 8'), findsOneWidget);
    await tester.tap(find.text('图鉴').last);
    await tester.pumpAndSettle();
    expect(find.text('图鉴 1 / 8'), findsOneWidget);
    expect(find.text('2. 自习精灵'), findsOneWidget);
    await tester.tap(find.text('我的精灵').last);
    await tester.pumpAndSettle();
    expect(find.text('我的精灵 · 1 只'), findsOneWidget);
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    expect(find.text('1 / 8'), findsOneWidget);
    expect(paths, ['summary', 'dex', 'bag', 'nearby']);
  });
}
