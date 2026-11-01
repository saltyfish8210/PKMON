/// 会话端口：网络层只从这里读取 token 与代次，不依赖账号页面。
class SessionToken {
  const SessionToken({required this.value, required this.generation});

  final String value;

  /// 账号切换或退出时由账号侧自增；网络层用它丢弃上一代会话的迟到响应。
  final int generation;
}

abstract interface class TokenProvider {
  Future<SessionToken?> current();
}

/// 测试与独立开发用：显式设置 token 与代次。
class StaticTokenProvider implements TokenProvider {
  StaticTokenProvider({this.token, this.generation = 0});

  String? token;
  int generation;

  @override
  Future<SessionToken?> current() async {
    final value = token;
    if (value == null || value.isEmpty) return null;
    return SessionToken(value: value, generation: generation);
  }

  Future<void> setToken(String? value) async {
    token = value;
  }

  void bumpGeneration() => generation++;
}
