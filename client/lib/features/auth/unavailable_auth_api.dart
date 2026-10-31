import '../../data/api/api_failure.dart';
import '../../data/api/auth_api.dart';
import '../../data/model/auth_models.dart';

/// 骨架期的账号端口替身。
///
/// 服务端尚未实现账号接口，也不允许伪造登录成功；所有方法统一抛出
/// 明确的「未接入」错误，由页面显示给用户。
class UnavailableAuthApi implements AuthApi {
  const UnavailableAuthApi();

  static const ApiFailure _failure = ApiFailure(
    FailureKind.serviceUnavailable,
    '账号接口未接入（骨架）',
    code: 50301,
  );

  @override
  Future<UserView> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    throw _failure;
  }

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    throw _failure;
  }

  @override
  Future<void> logout() async {
    throw _failure;
  }

  @override
  Future<UserView> me() async {
    throw _failure;
  }
}
