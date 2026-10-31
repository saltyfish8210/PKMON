import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/features/auth/auth_error_messages.dart';

void main() {
  test('40101 统一为用户名或密码错误', () {
    expect(
      authFailureMessage(
        const ApiFailure(FailureKind.unauthorized, '服务端细节', code: 40101),
      ),
      '用户名或密码错误',
    );
  });

  test('40901 显示用户名已被占用', () {
    expect(
      authFailureMessage(
        const ApiFailure(FailureKind.conflict, 'exists', code: 40901),
      ),
      '用户名已被占用',
    );
  });

  test('超时与断网提示检查网络', () {
    expect(
      authFailureMessage(const ApiFailure(FailureKind.timeout, 'timeout')),
      '网络异常，请检查网络后重试',
    );
    expect(
      authFailureMessage(const ApiFailure(FailureKind.network, 'offline')),
      '网络异常，请检查网络后重试',
    );
  });

  test('账号接口未接入时保留明确提示', () {
    expect(
      authFailureMessage(
        const ApiFailure(
          FailureKind.serviceUnavailable,
          '账号接口未接入（骨架）',
          code: 50301,
        ),
      ),
      '账号接口未接入（骨架）',
    );
  });
}
