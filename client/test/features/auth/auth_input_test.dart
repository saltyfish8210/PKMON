import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/features/auth/auth_input.dart';

void main() {
  group('登录输入', () {
    test('合法输入通过', () {
      expect(validateLoginInput('campus_demo', 'secret'), isNull);
    });

    test('用户名为空或只有空白', () {
      expect(validateLoginInput('', 'secret'), '请输入用户名');
      expect(validateLoginInput('   ', 'secret'), '请输入用户名');
    });

    test('用户名超过 24 个字符', () {
      expect(validateLoginInput('u' * 25, 'secret'), '用户名不能超过 24 个字符');
    });

    test('密码为空', () {
      expect(validateLoginInput('campus_demo', ''), '请输入密码');
    });
  });

  group('注册输入', () {
    test('昵称为空', () {
      expect(
        validateRegisterInput('campus_demo', 'secret', '   '),
        '请输入昵称',
      );
    });

    test('昵称最多 20 个 Unicode 字符', () {
      expect(validateRegisterInput('campus_demo', 'secret', '昵' * 20), isNull);
      expect(
        validateRegisterInput('campus_demo', 'secret', '昵' * 21),
        '昵称不能超过 20 个字符',
      );
    });

    test('用户名与密码规则优先于昵称', () {
      expect(validateRegisterInput('', '', ''), '请输入用户名');
      expect(validateRegisterInput('campus_demo', '', ''), '请输入密码');
    });
  });
}
