import 'dart:math';

/// 一次业务提交的请求标识生成器。
///
/// 约定：同一次提交的网络重试复用原 requestId；用户重新作答必须重新生成。
/// 默认生成 UUID v4，与服务端 VARCHAR(36) 幂等键约定一致。
typedef RequestIdGenerator = String Function();

String defaultRequestIdGenerator() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
