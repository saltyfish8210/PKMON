import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/fakes/fakes.dart';
import 'package:pkmon_app/features/auth/auth_controller.dart';
import 'package:pkmon_app/features/auth/session_store.dart';
import 'package:pkmon_app/features/auth/unavailable_auth_api.dart';

import '../../support/auth_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 10, 31, 12);

  group('恢复会话', () {
    test('没有本地会话 → 未登录', () async {
      final controller = AuthController(
        api: FakeAuthApi(),
        store: InMemorySessionStore(),
        clock: () => now,
      );

      await controller.restore();

      expect(controller.status, AuthStatus.signedOut);
      expect(controller.session, isNull);
    });

    test('有效会话 → 已登录', () async {
      final store = InMemorySessionStore(initial: testSession());
      final controller = AuthController(
        api: FakeAuthApi(),
        store: store,
        clock: () => now,
      );

      await controller.restore();

      expect(controller.status, AuthStatus.signedIn);
      expect(controller.session?.token, 'test-token');
    });

    test('到期时刻即算过期，清除会话和缓存', () async {
      var cacheCleared = 0;
      final store = InMemorySessionStore(
        initial: testSession(expiresAt: now),
      );
      final controller = AuthController(
        api: FakeAuthApi(),
        store: store,
        clock: () => now,
        onClearCache: () async => cacheCleared++,
      );

      await controller.restore();

      expect(controller.status, AuthStatus.signedOut);
      expect(await store.load(), isNull);
      expect(cacheCleared, 1);
      expect(controller.error, '登录已过期，请重新登录');
    });
  });

  group('登录', () {
    test('成功：保存会话并进入已登录', () async {
      final api = FakeAuthApi();
      final store = InMemorySessionStore();
      final controller = AuthController(api: api, store: store);

      final ok = await controller.login('  campus_demo  ', 'secret');

      expect(ok, isTrue);
      expect(controller.status, AuthStatus.signedIn);
      expect(controller.session?.user.username, 'campus_demo');
      expect(await store.load(), isNotNull);
      expect(api.calls, contains('login:campus_demo'));
    });

    test('错误口令：统一提示且不保存会话', () async {
      final api = FakeAuthApi(
        failure: const ApiFailure(
          FailureKind.unauthorized,
          '服务端细节不展示',
          code: 40101,
        ),
      );
      final store = InMemorySessionStore();
      final controller = AuthController(api: api, store: store);

      final ok = await controller.login('campus_demo', 'wrong');

      expect(ok, isFalse);
      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, '用户名或密码错误');
      expect(await store.load(), isNull);
    });

    test('空输入不发请求', () async {
      final api = FakeAuthApi();
      final controller = AuthController(api: api, store: InMemorySessionStore());

      expect(await controller.login('   ', 'secret'), isFalse);
      expect(controller.error, '请输入用户名');
      expect(await controller.login('campus_demo', ''), isFalse);
      expect(controller.error, '请输入密码');
      expect(api.calls, isEmpty);
    });

    test('连续点击只发一次请求', () async {
      final api = BlockingAuthApi();
      final controller = AuthController(
        api: api,
        store: InMemorySessionStore(),
      );

      final first = controller.login('campus_demo', 'secret');
      final second = controller.login('campus_demo', 'secret');

      expect(await second, isFalse);
      expect(api.loginCallCount, 1);
      expect(controller.busy, isTrue);

      api.completeLogin(testSession());
      expect(await first, isTrue);
      expect(controller.busy, isFalse);
    });

    test('不可用接口返回明确错误，不伪造成功', () async {
      final store = InMemorySessionStore();
      final controller = AuthController(
        api: const UnavailableAuthApi(),
        store: store,
      );

      final ok = await controller.login('campus_demo', 'secret');

      expect(ok, isFalse);
      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, '账号接口未接入（骨架）');
      expect(await store.load(), isNull);
    });
  });

  group('注册', () {
    test('成功不自动登录，只提示请登录', () async {
      final controller = AuthController(
        api: FakeAuthApi(),
        store: InMemorySessionStore(),
      );

      final user = await controller.register('campus_demo', 'secret', '校园同学');

      expect(user?.username, 'campus_demo');
      expect(controller.status, isNot(AuthStatus.signedIn));
      expect(controller.notice, '注册成功，请登录');
    });

    test('用户名冲突显示占用提示', () async {
      final api = FakeAuthApi(
        failure: const ApiFailure(
          FailureKind.conflict,
          '服务器细节',
          code: 40901,
        ),
      );
      final controller = AuthController(
        api: api,
        store: InMemorySessionStore(),
      );

      final user = await controller.register('campus_demo', 'secret', '校园同学');

      expect(user, isNull);
      expect(controller.error, '用户名已被占用');
    });

    test('昵称超过 20 个字符不发请求', () async {
      final api = FakeAuthApi();
      final controller = AuthController(
        api: api,
        store: InMemorySessionStore(),
      );

      final user = await controller.register('campus_demo', 'secret', '昵' * 21);

      expect(user, isNull);
      expect(controller.error, '昵称不能超过 20 个字符');
      expect(api.calls, isEmpty);
    });

    test('用户名超过 24 个字符不发请求', () async {
      final api = FakeAuthApi();
      final controller = AuthController(
        api: api,
        store: InMemorySessionStore(),
      );

      final user = await controller.register('u' * 25, 'secret', '校园同学');

      expect(user, isNull);
      expect(controller.error, '用户名不能超过 24 个字符');
      expect(api.calls, isEmpty);
    });
  });

  group('退出与失效', () {
    test('退出成功：清会话、清缓存、回登录态', () async {
      var cacheCleared = 0;
      final store = InMemorySessionStore(initial: testSession());
      final api = FakeAuthApi();
      final controller = AuthController(
        api: api,
        store: store,
        onClearCache: () async => cacheCleared++,
      );
      await controller.restore();

      await controller.logout();

      expect(api.calls, contains('logout'));
      expect(await store.load(), isNull);
      expect(cacheCleared, 1);
      expect(controller.status, AuthStatus.signedOut);
      expect(controller.logoutRemoteFailed, isFalse);
    });

    test('远端退出失败：本地仍清除并标记失败', () async {
      var cacheCleared = 0;
      final store = InMemorySessionStore(initial: testSession());
      final api = FakeAuthApi(
        failure: const ApiFailure(FailureKind.network, '断网'),
      );
      final controller = AuthController(
        api: api,
        store: store,
        onClearCache: () async => cacheCleared++,
      );
      await controller.restore();

      await controller.logout();

      expect(await store.load(), isNull);
      expect(cacheCleared, 1);
      expect(controller.status, AuthStatus.signedOut);
      expect(controller.logoutRemoteFailed, isTrue);
    });

    test('401 统一处理：清会话并回登录态', () async {
      final store = InMemorySessionStore(initial: testSession());
      final controller = AuthController(
        api: FakeAuthApi(),
        store: store,
      );
      await controller.restore();

      await controller.handleUnauthorized();

      expect(await store.load(), isNull);
      expect(controller.status, AuthStatus.signedOut);
      expect(controller.error, '登录已过期，请重新登录');
    });
  });
}
