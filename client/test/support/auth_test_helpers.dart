import 'dart:async';

import 'package:pkmon_app/data/api/auth_api.dart';
import 'package:pkmon_app/data/model/auth_models.dart';

const UserView testUser = UserView(
  userId: '11111111-1111-4111-8111-111111111111',
  username: 'campus_demo',
  nickname: '校园同学',
);

LoginResult testSession({
  String token = 'test-token',
  DateTime? expiresAt,
}) {
  return LoginResult(
    token: token,
    expiresAt: expiresAt ?? DateTime.utc(2030, 1, 1),
    user: testUser,
  );
}

/// 可手动放行的登录替身，用来验证加载态和重复点击。
class BlockingAuthApi implements AuthApi {
  final Completer<LoginResult> _login = Completer<LoginResult>();
  final List<String> calls = <String>[];

  int get loginCallCount => calls.where((call) => call == 'login').length;

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
  }) {
    calls.add('login');
    return _login.future;
  }

  void completeLogin(LoginResult result) => _login.complete(result);

  @override
  Future<UserView> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    calls.add('register');
    return testUser;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
  }

  @override
  Future<UserView> me() async {
    calls.add('me');
    return testUser;
  }
}
