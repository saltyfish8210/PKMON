import '../../data/model/auth_models.dart';

/// 本机会话存储端口。
///
/// 页面与控制器只通过这个端口读写会话；网络层通过 [SessionTokenProvider]
/// 读取 token 与代次。持久化方式（安全存储/普通存储）尚未确定，
/// 当前提供内存实现，重启即失效。
abstract interface class SessionStore {
  /// 每次保存或清除都会自增；网络层用它丢弃上一代会话的迟到响应。
  int get generation;

  Future<LoginResult?> load();

  Future<void> save(LoginResult session);

  Future<void> clear();
}

/// 骨架与测试用的内存实现。
///
/// 明确不持久化：进程结束会话即丢失，不能当成“登录状态已保存”。
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore({LoginResult? initial}) : _session = initial;

  LoginResult? _session;
  int _generation = 0;

  @override
  int get generation => _generation;

  @override
  Future<LoginResult?> load() async => _session;

  @override
  Future<void> save(LoginResult session) async {
    _session = session;
    _generation++;
  }

  @override
  Future<void> clear() async {
    _session = null;
    _generation++;
  }
}
