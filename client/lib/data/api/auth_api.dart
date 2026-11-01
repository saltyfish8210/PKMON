import '../model/auth_models.dart';
import 'api_client.dart';

/// 账号端口。服务端 HTTP 尚未实现（闫昕分支契约），当前以 Fake 推进。
abstract interface class AuthApi {
  Future<UserView> register({
    required String username,
    required String password,
    required String nickname,
  });

  Future<LoginResult> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<UserView> me();
}

class HttpAuthApi implements AuthApi {
  const HttpAuthApi(this._client);

  final ApiClient _client;

  @override
  Future<UserView> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    final data = await _client.post(
      '/auth/register',
      authenticated: false,
      body: <String, dynamic>{
        'username': username,
        'password': password,
        'nickname': nickname,
      },
    );
    return UserView.fromJson(data);
  }

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post(
      '/auth/login',
      authenticated: false,
      body: <String, dynamic>{'username': username, 'password': password},
    );
    return LoginResult.fromJson(data);
  }

  @override
  Future<void> logout() async {
    await _client.post('/auth/logout');
  }

  @override
  Future<UserView> me() async {
    final data = await _client.get('/users/me');
    return UserView.fromJson(data);
  }
}
