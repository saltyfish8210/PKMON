import '../../data/api/token_provider.dart';
import 'session_store.dart';

/// 把 [SessionStore] 适配成网络层需要的 [TokenProvider]。
///
/// 只暴露 token 与代次；网络层据此丢弃账号切换后的迟到响应。
class SessionTokenProvider implements TokenProvider {
  SessionTokenProvider(this._store);

  final SessionStore _store;

  @override
  Future<SessionToken?> current() async {
    final session = await _store.load();
    if (session == null || session.token.isEmpty) return null;
    return SessionToken(
      value: session.token,
      generation: _store.generation,
    );
  }
}
