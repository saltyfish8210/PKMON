import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/features/auth/auth_input.dart';

/// 规则必须与服务端 AuthRules 一致：
/// 用户名 ^[A-Za-z0-9_]{3,24}$；密码 12–64 字符且 ≤72 字节；昵称 1–20 字符。
void main() {
  const okPassword = 'pkmon-secret-1';

  group('登录输入', () {
    test('合法输入通过', () {
      expect(validateLoginInput('campus_demo', okPassword), isNull);
      expect(validateLoginInput('ab_1', okPassword), isNull);
    });

    test('用户名为空或只有空白', () {
      expect(validateLoginInput('', okPassword), '请输入用户名');
      expect(validateLoginInput('   ', okPassword), '请输入用户名');
    });

    test('用户名少于 3 位或超过 24 位', () {
      expect(validateLoginInput('ab', okPassword), '用户名需为 3–24 位字母、数字或下划线');
      expect(validateLoginInput('u' * 25, okPassword), '用户名需为 3–24 位字母、数字或下划线');
    });

    test('用户名含中文、空格或符号时不通过', () {
      expect(validateLoginInput('闫昕', okPassword), '用户名需为 3–24 位字母、数字或下划线');
      expect(validateLoginInput('campus demo', okPassword), '用户名需为 3–24 位字母、数字或下划线');
      expect(validateLoginInput('campus-demo', okPassword), '用户名需为 3–24 位字母、数字或下划线');
    });

    test('密码为空', () {
      expect(validateLoginInput('campus_demo', ''), '请输入密码');
    });

    test('密码短于 12 位或长于 64 位', () {
      expect(validateLoginInput('campus_demo', 'short'), '密码需为 12–64 位字符');
      expect(validateLoginInput('campus_demo', 'p' * 11), '密码需为 12–64 位字符');
      expect(validateLoginInput('campus_demo', 'p' * 12), isNull);
      expect(validateLoginInput('campus_demo', 'p' * 64), isNull);
      expect(validateLoginInput('campus_demo', 'p' * 65), '密码需为 12–64 位字符');
    });

    test('密码 UTF-8 超过 72 字节时提示过长', () {
      // 25 个 3 字节汉字 = 75 字节，字符数在 12..64 之内但字节超限。
      expect(
        validateLoginInput('campus_demo', '密' * 25),
        '密码过长（超过 72 字节），请缩短后重试',
      );
    });
  });

  group('注册输入', () {
    test('昵称为空', () {
      expect(
        validateRegisterInput('campus_demo', okPassword, '   '),
        '请输入昵称',
      );
    });

    test('昵称最多 20 个 Unicode 字符', () {
      expect(validateRegisterInput('campus_demo', okPassword, '昵' * 20), isNull);
      expect(
        validateRegisterInput('campus_demo', okPassword, '昵' * 21),
        '昵称不能超过 20 个字符',
      );
    });

    test('用户名与密码规则优先于昵称', () {
      expect(validateRegisterInput('', '', ''), '请输入用户名');
      expect(validateRegisterInput('campus_demo', '', ''), '请输入密码');
      expect(validateRegisterInput('campus_demo', 'short', ''), '密码需为 12–64 位字符');
    });

    test('三项都合法时通过', () {
      expect(validateRegisterInput('campus_demo', okPassword, '校园同学'), isNull);
    });
  });
}
