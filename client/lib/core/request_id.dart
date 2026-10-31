import 'dart:math';

/// 请求标识生成器。
///
/// 约定（与网络层一致）：一次业务提交只生成一次；网络重试复用同一个 id；
/// 用户重新发起一次新操作时才生成新的 id。
///
/// 实现为 UUID v4，不引入第三方依赖：
/// 16 个安全随机字节，按 RFC 4122 设置版本位与变体位。
class RequestId {
  RequestId._();

  static final Random _random = Random.secure();

  /// 生成一个小写的 UUID v4 字符串。
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final text = bytes.map(hex).join();

    return '${text.substring(0, 8)}-'
        '${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-'
        '${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }
}

/// 跟踪一次业务提交的 requestId。
///
/// 页面或控制器在首次提交时读取 [value]，之后的重试继续读取同一个值；
/// 只有明确开始一次新操作时才调用 [reset]。
class RequestIdTracker {
  RequestIdTracker({String Function()? generate})
      : _generate = generate ?? RequestId.generate;

  final String Function() _generate;
  String? _value;

  String get value => _value ??= _generate();

  /// 丢弃旧 id，下一次 [value] 会生成新的 UUID。
  void reset() {
    _value = null;
  }
}
