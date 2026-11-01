import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/fakes/fakes.dart';
import 'package:pkmon_app/features/auth/app_gate.dart';
import 'package:pkmon_app/features/auth/auth_controller.dart';
import 'package:pkmon_app/features/auth/session_store.dart';

import '../../support/auth_test_helpers.dart';

Widget gate(AuthController controller) {
  return MaterialApp(
    home: AppGate(
      controller: controller,
      homeBuilder: (_) => const Text('HOME'),
    ),
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 31, 12);

  testWidgets('首帧显示恢复中，无会话进入登录页', (tester) async {
    final controller = AuthController(
      api: FakeAuthApi(),
      store: InMemorySessionStore(),
      clock: () => now,
    );

    await tester.pumpWidget(gate(controller));

    expect(find.text('正在恢复登录状态…'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('登录 PKMon'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('进入演示不创建也不保存会话', (tester) async {
    final store = InMemorySessionStore();
    final controller = AuthController(
      api: FakeAuthApi(),
      store: store,
      clock: () => now,
    );

    await tester.pumpWidget(gate(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('进入演示（不登录）'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(await store.load(), isNull);
  });

  testWidgets('登录成功保存会话并进入主界面', (tester) async {
    final store = InMemorySessionStore();
    final controller = AuthController(
      api: FakeAuthApi(),
      store: store,
      clock: () => now,
    );

    await tester.pumpWidget(gate(controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login_username')), 'campus_demo');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(await store.load(), isNotNull);
  });

  testWidgets('本地会话已过期时回到登录页并说明原因', (tester) async {
    final store = InMemorySessionStore(
      initial: testSession(expiresAt: now),
    );
    final controller = AuthController(
      api: FakeAuthApi(),
      store: store,
      clock: () => now,
    );

    await tester.pumpWidget(gate(controller));
    await tester.pumpAndSettle();

    expect(find.text('登录 PKMon'), findsOneWidget);
    expect(find.text('登录已过期，请重新登录'), findsOneWidget);
  });

  testWidgets('401 后从主界面回到登录页', (tester) async {
    final store = InMemorySessionStore(initial: testSession());
    final controller = AuthController(
      api: FakeAuthApi(),
      store: store,
      clock: () => now,
    );

    await tester.pumpWidget(gate(controller));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    await controller.handleUnauthorized();
    await tester.pumpAndSettle();

    expect(find.text('登录 PKMon'), findsOneWidget);
    expect(await store.load(), isNull);
  });
}
