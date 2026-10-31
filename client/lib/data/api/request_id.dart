import 'dart:math';

/// 一次业务提交的请求标识生成器。
///
/// 约定：同一次提交的网络重试复用原 requestId；用户重新作答必须重新生成。
/// 默认实现不引入 uuid 依赖：时间戳 + 安全随机数，足够本地唯一。
typedef RequestIdGenerator = String Function();

String defaultRequestIdGenerator() {
  final random = Random.secure();
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  final suffix = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '$time-$suffix';
}
