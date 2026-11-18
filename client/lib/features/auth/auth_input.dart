import 'dart:convert';

/// 账号输入的纯规则。
///
/// 这里的每一条都必须与服务端 `AuthRules` 保持一致，否则会出现
/// “前端放行、后端 400、界面只显示『输入内容不正确』”的体验问题。
/// 服务端规则（server/src/main/java/edu/pkmon/user/service/AuthRules.java）：
///   用户名 ^[A-Za-z0-9_]{3,24}$
///   密码   4–64 个字符，且 UTF-8 编码后不超过 72 字节
///   昵称   1–20 个字符，去除首尾空白后非空
class AuthInputRules {
  AuthInputRules._();

  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 24;
  static const int nicknameMaxLength = 20;
  static const int passwordMinLength = 4;
  static const int passwordMaxLength = 64;
  static const int passwordMaxBytes = 72;

  /// 与服务端完全一致的用户名字符集与长度。
  static final RegExp usernamePattern = RegExp(r'^[A-Za-z0-9_]{3,24}$');

  static const String usernameHint = '3–24 位字母、数字或下划线';
  static const String passwordHint = '4–64 位字符';
  static const String nicknameHint = '1–20 个字符，展示在图鉴与收藏页';
}

/// 用户名校验；通过返回 null。
String? validateUsername(String username) {
  final name = username.trim();
  if (name.isEmpty) return '请输入用户名';
  if (!AuthInputRules.usernamePattern.hasMatch(name)) {
    return '用户名需为 3–24 位字母、数字或下划线';
  }
  return null;
}

/// 密码校验；通过返回 null。登录与注册使用同一套规则，与服务端一致。
String? validatePassword(String password) {
  if (password.isEmpty) return '请输入密码';
  final length = password.runes.length;
  if (length < AuthInputRules.passwordMinLength ||
      length > AuthInputRules.passwordMaxLength) {
    return '密码需为 4–64 位字符';
  }
  if (utf8.encode(password).length > AuthInputRules.passwordMaxBytes) {
    return '密码过长（超过 72 字节），请缩短后重试';
  }
  return null;
}

/// 昵称校验；通过返回 null。
String? validateNickname(String nickname) {
  final nick = nickname.trim();
  if (nick.isEmpty) return '请输入昵称';
  if (nick.runes.length > AuthInputRules.nicknameMaxLength) {
    return '昵称不能超过 20 个字符';
  }
  return null;
}

/// 登录输入校验；通过返回 null。
String? validateLoginInput(String username, String password) =>
    validateUsername(username) ?? validatePassword(password);

/// 注册输入校验；通过返回 null。
String? validateRegisterInput(
  String username,
  String password,
  String nickname,
) =>
    validateUsername(username) ??
    validatePassword(password) ??
    validateNickname(nickname);
