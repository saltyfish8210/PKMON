import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/fakes/fakes.dart';
import 'package:pkmon_app/features/auth/auth_controller.dart';
import 'package:pkmon_app/features/auth/login_page.dart';
import 'package:pkmon_app/features/auth/session_store.dart';
import 'package:pkmon_app/widgets/app_buttons.dart';

import '../../support/auth_test_helpers.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('显示骨架说明、演示按钮和注册后置说明', (tester) async {
    final controller = AuthController(
      api: FakeAuthApi(),
      store: InMemorySessionStore(),
    );

    await tester.pumpWidget(wrap(LoginPage(
      controller: controller,
      onEnterDemo: () {},
    )));

    expect(find.text('登录 PKMon'), findsOneWidget);
    expect(find.text(LoginPage.skeletonNotice), findsOneWidget);
    expect(find.text('进入演示（不登录）'), findsOneWidget);
    expect(find.text(LoginPage.registerNotice), findsOneWidget);
  });

  testWidgets('空输入只提示，不发请求', (tester) async {
    final api = FakeAuthApi();
    final controller = AuthController(
      api: api,
      store: InMemorySessionStore(),
    );

    await tester.pumpWidget(wrap(LoginPage(
      controller: controller,
      onEnterDemo: () {},
    )));
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('请输入用户名'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('错误口令显示统一提示', (tester) async {
    final api = FakeAuthApi(
      failure: const ApiFailure(
        FailureKind.unauthorized,
        '服务端细节',
        code: 40101,
      ),
    );
    final controller = AuthController(
      api: api,
      store: InMemorySessionStore(),
    );

    await tester.pumpWidget(wrap(LoginPage(
      controller: controller,
      onEnterDemo: () {},
    )));
    await tester.enterText(find.byKey(const Key('login_username')), 'campus_demo');
    await tester.enterText(find.byKey(const Key('login_password')), 'wrong');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('用户名或密码错误'), findsOneWidget);
    expect(controller.status, AuthStatus.signedOut);
  });

  testWidgets('提交中禁用按钮并显示登录中', (tester) async {
    final api = BlockingAuthApi();
    final controller = AuthController(
      api: api,
      store: InMemorySessionStore(),
    );

    await tester.pumpWidget(wrap(LoginPage(
      controller: controller,
      onEnterDemo: () {},
    )));
    await tester.enterText(find.byKey(const Key('login_username')), 'campus_demo');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    expect(find.text('登录中…'), findsOneWidget);
    final button = tester.widget<PrimaryButton>(
      find.byKey(const Key('login_submit')),
    );
    expect(button.onPressed, isNull);

    api.completeLogin(testSession());
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('小屏可滚动且不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AuthController(
      api: FakeAuthApi(),
      store: InMemorySessionStore(),
    );

    await tester.pumpWidget(wrap(LoginPage(
      controller: controller,
      onEnterDemo: () {},
    )));

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('演示按钮只回调一次', (tester) async {
    var demo = 0;
    final controller = AuthController(
      api: FakeAuthApi(),
      store: InMemorySessionStore(),
    );

    await tester.pumpWidget(wrap(LoginPage(
      controller: controller,
      onEnterDemo: () => demo++,
    )));
    await tester.tap(find.byKey(const Key('login_demo')));
    await tester.pump();

    expect(demo, 1);
  });
}
