import '../data/api/request_id.dart' as network;

/// 请求标识入口。
///
/// 生成器只保留一份：直接复用网络层的 `defaultRequestIdGenerator`，
/// 本类不再自己生成 UUID，避免同一项目里出现两套 id 语义。
/// 本文件只补“一次业务操作生成一次、重试复用”的跟踪逻辑。
class RequestId {
  RequestId._();

  static String generate() => network.defaultRequestIdGenerator();
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

  /// 丢弃旧 id，下一次 [value] 会生成新的 id。
  void reset() {
    _value = null;
  }
}
