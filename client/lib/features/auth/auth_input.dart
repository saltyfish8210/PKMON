/// 账号输入的纯规则。
///
/// 控制器和页面共用同一套校验，避免两处提示不一致。
class AuthInputRules {
  AuthInputRules._();

  static const int usernameMaxLength = 24;
  static const int nicknameMaxLength = 20;
}

/// 登录输入校验；通过返回 null。
String? validateLoginInput(String username, String password) {
  final name = username.trim();
  if (name.isEmpty) return '请输入用户名';
  if (name.runes.length > AuthInputRules.usernameMaxLength) {
    return '用户名不能超过 24 个字符';
  }
  if (password.isEmpty) return '请输入密码';
  return null;
}

/// 注册输入校验；通过返回 null。
String? validateRegisterInput(
  String username,
  String password,
  String nickname,
) {
  final loginError = validateLoginInput(username, password);
  if (loginError != null) return loginError;

  final nick = nickname.trim();
  if (nick.isEmpty) return '请输入昵称';
  if (nick.runes.length > AuthInputRules.nicknameMaxLength) {
    return '昵称不能超过 20 个字符';
  }
  return null;
}
