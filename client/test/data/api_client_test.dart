import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/api/token_provider.dart';

import 'test_support.dart';

void main() {
  group('ApiClient 信封与错误', () {
    test('成功信封解析 data', () async {
      final client = clientWith(
        MockClient((request) async => jsonResponse(fixture('10-summary.json'))),
      );
      final data = await client.get('/collection/summary');
      expect(data['collectedSpeciesCount'], 1);
      expect(data['captureCount'], 1);
      client.close();
    });

    test('业务码映射为对应 kind', () async {
      Future<FailureKind> kindOf(int code, int status) async {
        final client = clientWith(MockClient(
          (request) async => envelope(null, code: code, message: '错误'),
        ));
        try {
          await client.get('/x');
          fail('应当抛出 ApiFailure');
        } on ApiFailure catch (failure) {
          expect(failure.code, code);
          return failure.kind;
        } finally {
          client.close();
        }
      }

      expect(await kindOf(40001, 400), FailureKind.badRequest);
      expect(await kindOf(40401, 404), FailureKind.notFound);
      expect(await kindOf(40902, 409), FailureKind.conflict);
      expect(await kindOf(41001, 410), FailureKind.expired);
      expect(await kindOf(50301, 503), FailureKind.serviceUnavailable);
      expect(await kindOf(40101, 401), FailureKind.unauthorized);
    });

    test('HTTP 非 2xx 且无信封时按状态兜底', () async {
      final client = clientWith(
        MockClient((request) async => http.Response('oops', 500)),
      );
      await expectLater(
        client.get('/x'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.server)
            .having((e) => e.httpStatus, 'httpStatus', 500)),
      );
      client.close();
    });

    test('超时映射为 timeout', () async {
      final client = clientWith(
        MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          return envelope(<String, dynamic>{});
        }),
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        client.get('/x'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.timeout)),
      );
      client.close();
    });

    test('网络异常映射为 network', () async {
      final client = clientWith(
        MockClient((request) async => throw http.ClientException('boom')),
      );
      await expectLater(
        client.get('/x'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.network)),
      );
      client.close();
    });

    test('data 非对象视为契约违约', () async {
      final client = clientWith(
        MockClient((request) async => envelope(<Object>['a', 'b'])),
      );
      await expectLater(
        client.get('/x'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.protocol)),
      );
      client.close();
    });
  });

  group('ApiClient 身份与代次', () {
    test('受保护请求注入 Bearer', () async {
      String? authorization;
      final client = clientWith(MockClient((request) async {
        authorization = request.headers['Authorization'];
        return envelope(<String, dynamic>{});
      }));
      await client.get('/users/me');
      expect(authorization, 'Bearer test-token');
      client.close();
    });

    test('无 token 时不发请求，直接 unauthorized', () async {
      var requests = 0;
      final client = clientWith(
        MockClient((request) async {
          requests++;
          return envelope(<String, dynamic>{});
        }),
        tokens: StaticTokenProvider(),
      );
      await expectLater(
        client.get('/users/me'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.unauthorized)),
      );
      expect(requests, 0);
      client.close();
    });

    test('40101 触发一次 onUnauthorized', () async {
      var calls = 0;
      final client = clientWith(
        MockClient((request) async => envelope(null, code: 40101, message: '失效')),
        onUnauthorized: () => calls++,
      );
      await expectLater(client.get('/users/me'), throwsA(isA<ApiFailure>()));
      expect(calls, 1);
      client.close();
    });

    test('代次变化丢弃迟到响应', () async {
      final tokens = StaticTokenProvider(token: 'token', generation: 1);
      final client = clientWith(
        MockClient((request) async {
          tokens.bumpGeneration();
          return envelope(<String, dynamic>{'userId': 'u1'});
        }),
        tokens: tokens,
      );
      await expectLater(
        client.get('/users/me'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.staleSession)),
      );
      client.close();
    });

    test('UTF-8 中文响应按字节解码', () async {
      final client = clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'challengeId': 'c1',
          'spawnId': 's1',
          'speciesId': 'siege_lion',
          'speciesName': '攻城狮',
          'questionId': 'q1',
          'questionText': '执行 print("hello world") 之后，控制台会输出什么？',
          'options': <Object>[
            {'optionId': 'A', 'text': 'hello world'},
            {'optionId': 'B', 'text': '程序报错'},
          ],
          'expiresAt': '2026-10-19T02:05:00Z',
        }),
      ));
      final data = await client.post('/capture/challenge');
      expect(data['speciesName'], '攻城狮');
      expect((data['questionText'] as String).contains('控制台'), isTrue);
      client.close();
    });
  });
}
