import '../../data/api/api_failure.dart';

/// 把网络层错误翻译成页面可直接显示的中文提示。
///
/// 40101 统一为「用户名或密码错误」，不区分账号不存在与口令错误；
/// 服务端返回的原始 message 不直接上屏，避免泄露实现细节。
String authFailureMessage(ApiFailure failure) => switch (failure.kind) {
      FailureKind.badRequest => '输入内容不正确',
      FailureKind.unauthorized => '用户名或密码错误',
      FailureKind.notFound => '账号操作未完成，请重试',
      FailureKind.conflict => '用户名已被占用',
      FailureKind.expired => '操作已过期，请重试',
      FailureKind.serviceUnavailable =>
        failure.message.isEmpty ? '账号服务暂不可用' : failure.message,
      FailureKind.timeout || FailureKind.network => '网络异常，请检查网络后重试',
      FailureKind.staleSession => '会话已切换，请重试',
      FailureKind.protocol => '服务返回异常，请稍后重试',
      FailureKind.server => '账号服务暂不可用',
    };
