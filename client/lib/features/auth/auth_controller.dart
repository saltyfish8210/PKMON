// 依赖字段保持私有，避免页面绕过控制器直接调用网络或存储。
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../data/api/api_failure.dart';
import '../../data/api/auth_api.dart';
import '../../data/model/auth_models.dart';
import 'session_store.dart';

enum AuthStatus { unknown, restoring, signedOut, signedIn }

/// 账号与公共入口的控制器。
///
/// 职责：
/// - 调用注入的 [AuthApi]，不自己发 HTTP；
/// - 登录成功后写入 [SessionStore]，退出/过期/401 时清除本地会话与业务缓存；
/// - 对页面暴露 loading、error、notice 与状态，页面只负责显示。
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi api,
    required SessionStore store,
    DateTime Function()? clock,
    Future<void> Function()? onClearCache,
  })  : _api = api,
        _store = store,
        _clock = clock ?? DateTime.now,
        _onClearCache = onClearCache;

  static const int usernameMaxLength = 24;
  static const int nicknameMaxLength = 20;

  final AuthApi _api;
  final SessionStore _store;
  final DateTime Function() _clock;
  final Future<void> Function()? _onClearCache;

  AuthStatus _status = AuthStatus.unknown;
  LoginResult? _session;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _logoutRemoteFailed = false;
  bool _disposed = false;

  AuthStatus get status => _status;
  LoginResult? get session => _session;
  String? get error => _error;
  String? get notice => _notice;
  bool get busy => _busy;

  /// 退出时远端调用失败（本地会话仍已清除）。
  bool get logoutRemoteFailed => _logoutRemoteFailed;

  /// 起步时读取本地会话。只做本地过期判断，服务端校验以 401 为准。
  Future<void> restore() async {
    _status = AuthStatus.restoring;
    _emit();

    try {
      final session = await _store.load();
      if (session == null) {
        _status = AuthStatus.signedOut;
        return;
      }
      if (!session.expiresAt.isAfter(_clock())) {
        await _clearLocal();
        _error = '登录已过期，请重新登录';
        return;
      }
      _session = session;
      _status = AuthStatus.signedIn;
      _error = null;
    } catch (_) {
      await _clearLocal();
      _error = '读取本地会话失败，请重新登录';
    } finally {
      _emit();
    }
  }

  /// 登录。返回是否成功；成功后页面由 [AuthStatus.signedIn] 驱动。
  Future<bool> login(String username, String password) async {
    if (_busy) return false;

    final name = username.trim();
    final inputError = _validateLoginInput(name, password);
    if (inputError != null) {
      _error = inputError;
      _emit();
      return false;
    }

    _busy = true;
    _error = null;
    _notice = null;
    _logoutRemoteFailed = false;
    _emit();

    try {
      final result = await _api.login(username: name, password: password);
      await _store.save(result);
      _session = result;
      _status = AuthStatus.signedIn;
      return true;
    } on ApiFailure catch (failure) {
      _error = _messageFor(failure);
      if (_status != AuthStatus.signedIn) _status = AuthStatus.signedOut;
      return false;
    } catch (_) {
      _error = '账号服务暂不可用';
      if (_status != AuthStatus.signedIn) _status = AuthStatus.signedOut;
      return false;
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// 注册。成功不自动登录，只给出「请登录」提示。
  Future<UserView?> register(
    String username,
    String password,
    String nickname,
  ) async {
    if (_busy) return null;

    final name = username.trim();
    final nick = nickname.trim();
    final inputError = _validateRegisterInput(name, password, nick);
    if (inputError != null) {
      _error = inputError;
      _emit();
      return null;
    }

    _busy = true;
    _error = null;
    _notice = null;
    _emit();

    try {
      final user = await _api.register(
        username: name,
        password: password,
        nickname: nick,
      );
      _notice = '注册成功，请登录';
      return user;
    } on ApiFailure catch (failure) {
      _error = _messageFor(failure);
      return null;
    } catch (_) {
      _error = '账号服务暂不可用';
      return null;
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// 退出。远端失败也一定清除本地会话与缓存，只记录失败标记。
  Future<void> logout() async {
    if (_busy) return;

    _busy = true;
    _error = null;
    _notice = null;
    _logoutRemoteFailed = false;
    _emit();

    try {
      await _api.logout();
    } on ApiFailure {
      _logoutRemoteFailed = true;
    } catch (_) {
      _logoutRemoteFailed = true;
    } finally {
      await _clearLocal();
      _busy = false;
      _emit();
    }
  }

  /// 收到 40101 时统一处理：清会话、清缓存、回登录态。
  Future<void> handleUnauthorized({
    String message = '登录已过期，请重新登录',
  }) async {
    await _clearLocal();
    _error = message;
    _notice = null;
    _emit();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _emit();
  }

  Future<void> _clearLocal() async {
    await _store.clear();
    _session = null;
    _status = AuthStatus.signedOut;
    try {
      await _onClearCache?.call();
    } catch (_) {
      // 缓存清理失败不阻断退出；下一次进入业务页会重新拉取。
    }
  }

  String? _validateLoginInput(String username, String password) {
    if (username.isEmpty) return '请输入用户名';
    if (username.runes.length > usernameMaxLength) return '用户名不能超过 24 个字符';
    if (password.isEmpty) return '请输入密码';
    return null;
  }

  String? _validateRegisterInput(
    String username,
    String password,
    String nickname,
  ) {
    if (username.isEmpty) return '请输入用户名';
    if (username.runes.length > usernameMaxLength) return '用户名不能超过 24 个字符';
    if (password.isEmpty) return '请输入密码';
    if (nickname.isEmpty) return '请输入昵称';
    if (nickname.runes.length > nicknameMaxLength) return '昵称不能超过 20 个字符';
    return null;
  }

  String _messageFor(ApiFailure failure) => switch (failure.kind) {
        FailureKind.badRequest => '输入内容不正确',
        FailureKind.unauthorized => '用户名或密码错误',
        FailureKind.notFound => '账号操作未完成，请重试',
        FailureKind.conflict => '用户名已被占用',
        FailureKind.expired => '操作已过期，请重试',
        FailureKind.serviceUnavailable =>
          failure.message.isEmpty ? '账号服务暂不可用' : failure.message,
        FailureKind.timeout ||
        FailureKind.network =>
          '网络异常，请检查网络后重试',
        FailureKind.staleSession => '会话已切换，请重试',
        FailureKind.protocol => '服务返回异常，请稍后重试',
        FailureKind.server => '账号服务暂不可用',
      };

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
