/// 网络层统一错误。
///
/// 页面与控制器只根据 [kind] 决定后续行为，不解析字符串、不看 HTTP 状态码。
/// `code` 是服务端业务码（可能为 null：超时、断网、代次变化等本地错误）。
enum FailureKind {
  badRequest,
  unauthorized,
  notFound,
  conflict,
  expired,
  serviceUnavailable,
  timeout,
  network,
  staleSession,
  protocol,
  server,
}

class ApiFailure implements Exception {
  const ApiFailure(this.kind, this.message, {this.code, this.httpStatus});

  factory ApiFailure.protocol(String message) =>
      ApiFailure(FailureKind.protocol, message);

  final FailureKind kind;
  final String message;
  final int? code;
  final int? httpStatus;

  /// 读操作或网络重试是否值得再试一次。
  bool get isRetryable => switch (kind) {
        FailureKind.timeout ||
        FailureKind.network ||
        FailureKind.serviceUnavailable ||
        FailureKind.server =>
          true,
        _ => false,
      };

  @override
  String toString() =>
      'ApiFailure(${kind.name}, code: $code, message: $message)';
}
