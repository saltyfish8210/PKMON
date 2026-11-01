import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/api/auth_api.dart';

import 'test_support.dart';

void main() {
  group('HttpAuthApi', () {
    test('注册：无 Authorization，成功返回 UserView', () async {
      late http.Request captured;
      final api = HttpAuthApi(clientWith(MockClient((request) async {
        captured = request;
        return envelope(<String, dynamic>{
          'userId': 'u1',
          'username': 'campus_demo',
          'nickname': '校园同学',
        });
      })));

      final user = await api.register(
        username: 'campus_demo',
        password: 'password-1234',
        nickname: '校园同学',
      );

      expect(captured.url.path, '/api/v1/auth/register');
      expect(captured.headers.containsKey('Authorization'), isFalse);
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['username'], 'campus_demo');
      expect(body['nickname'], '校园同学');
      expect(user.nickname, '校园同学');
    });

    test('登录：解析 token/expiresAt/user', () async {
      final api = HttpAuthApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'token': 'opaque-token',
          'expiresAt': '2026-10-31T10:00:00Z',
          'user': <String, dynamic>{
            'userId': 'u1',
            'username': 'campus_demo',
            'nickname': '校园同学',
          },
        }),
      )));

      final result = await api.login(
        username: 'campus_demo',
        password: 'password-1234',
      );

      expect(result.token, 'opaque-token');
      expect(result.expiresAt.isUtc, isTrue);
      expect(result.user.userId, 'u1');
    });

    test('me 带 Bearer', () async {
      String? authorization;
      final api = HttpAuthApi(clientWith(MockClient((request) async {
        authorization = request.headers['Authorization'];
        return envelope(<String, dynamic>{
          'userId': 'u1',
          'username': 'campus_demo',
          'nickname': '校园同学',
        });
      })));

      final user = await api.me();
      expect(authorization, 'Bearer test-token');
      expect(user.username, 'campus_demo');
    });

    test('退出无返回数据也可完成', () async {
      late http.Request captured;
      final api = HttpAuthApi(clientWith(MockClient((request) async {
        captured = request;
        return envelope(<String, dynamic>{});
      })));

      await api.logout();
      expect(captured.url.path, '/api/v1/auth/logout');
      expect(captured.method, 'POST');
    });

    test('用户名冲突映射为 conflict 且保留业务码', () async {
      final api = HttpAuthApi(clientWith(MockClient(
        (request) async => envelope(null, code: 40901, message: '用户名已存在'),
      )));

      await expectLater(
        api.register(
          username: 'campus_demo',
          password: 'password-1234',
          nickname: '校园同学',
        ),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.conflict)
            .having((e) => e.code, 'code', 40901)),
      );
    });
  });
}
