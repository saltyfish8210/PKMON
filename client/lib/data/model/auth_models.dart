import 'parsing.dart';

/// 当前用户公开资料。只包含服务端返回的三项，不含 token。
class UserView {
  const UserView({
    required this.userId,
    required this.username,
    required this.nickname,
  });

  factory UserView.fromJson(Map<String, dynamic> json) => UserView(
        userId: requireString(json, 'userId'),
        username: requireString(json, 'username'),
        nickname: requireString(json, 'nickname'),
      );

  final String userId;
  final String username;
  final String nickname;
}

/// 登录结果：token 只在内存/安全存储中使用，不进入日志与截图。
class LoginResult {
  const LoginResult({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        token: requireString(json, 'token'),
        expiresAt: requireUtcTime(json, 'expiresAt'),
        user: UserView.fromJson(asJsonMap(json['user'], 'user')),
      );

  final String token;
  final DateTime expiresAt;
  final UserView user;
}
