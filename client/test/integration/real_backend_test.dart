import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_client.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/api/auth_api.dart';
import 'package:pkmon_app/data/api/capture_api.dart';
import 'package:pkmon_app/data/api/collection_api.dart';
import 'package:pkmon_app/data/api/token_provider.dart';
import 'package:pkmon_app/data/model/capture_models.dart';

/// 真实后端联调测试（默认跳过）。
///
/// 运行前提：
///   1) 后端已启动：java -jar target/pkmon-server-0.1.0.jar
///      --pkmon.capture.dev-spawn-enabled=true
///   2) 设置环境变量 PKMON_REAL_BACKEND=1（可选 PKMON_API_BASE）
///   3) cd client && flutter test test/integration/real_backend_test.dart
///
/// 覆盖：注册/登录/me、开发遭遇、取题、答错、答对、幂等回放、40902 冲突、
/// 状态查询、收藏概览、无 token 401。数据写入服务端（默认内存库，重启即清）。
void main() {
  final enabled = Platform.environment['PKMON_REAL_BACKEND'] == '1';
  final base = Uri.parse(
    Platform.environment['PKMON_API_BASE'] ?? 'http://127.0.0.1:4180',
  );
  final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final username = 'qa_$suffix';
  const password = 'password-12345';

  group('真实后端联调', () {
    late ApiClient client;
    late StaticTokenProvider tokens;
    late HttpAuthApi auth;
    late HttpCaptureApi capture;
    late HttpCollectionApi collection;

    setUpAll(() async {
      if (!enabled) return;
      tokens = StaticTokenProvider();
      client = ApiClient(
        baseUrl: base,
        tokens: tokens,
        timeout: const Duration(seconds: 15),
      );
      auth = HttpAuthApi(client);
      capture = HttpCaptureApi(client);
      collection = HttpCollectionApi(client);

      await auth.register(
        username: username,
        password: password,
        nickname: '联调甲',
      );
      final login = await auth.login(username: username, password: password);
      await tokens.setToken(login.token);
    });

    tearDownAll(() {
      if (enabled) client.close();
    });

    test('登录后 me 返回本人', () async {
      final me = await auth.me();
      expect(me.username, username);
      expect(me.nickname, '联调甲');
    }, skip: !enabled);

    test('无 token 的受保护请求返回 40101', () async {
      final anonymous = ApiClient(baseUrl: base, tokens: StaticTokenProvider());
      await expectLater(
        HttpCollectionApi(anonymous).summary(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.unauthorized)),
      );
      anonymous.close();
    }, skip: !enabled);

    test('开发遭遇 → 取题 → 答错 → 答对 → 状态 → 概览', () async {
      final spawn = await capture.createDevSpawn(
        regionId: 'library_entrance',
        speciesId: 'siege_lion',
      );
      expect(spawn.spawnId, isNotEmpty);

      final challenge = await capture.challenge(spawnId: spawn.spawnId);
      expect(challenge.speciesName, isNotEmpty);
      expect(challenge.options.length, inInclusiveRange(2, 4));

      final wrongOption = challenge.options.firstWhere(
        (option) => option.optionId != 'A',
        orElse: () => challenge.options.last,
      );
      final wrongRequest = 'req-$suffix-wrong';
      final wrong = await capture.answer(
        challengeId: challenge.challengeId,
        requestId: wrongRequest,
        optionId: wrongOption.optionId,
      );
      expect(wrong.result, AnswerResult.wrong);
      expect(wrong.captureRecordId, isNull);

      final correctRequest = 'req-$suffix-correct';
      final correct = await capture.answer(
        challengeId: challenge.challengeId,
        requestId: correctRequest,
        optionId: 'A',
      );
      expect(correct.result, AnswerResult.correct);
      expect(correct.captureRecordId, isNotNull);

      // 幂等：同一 requestId + 同内容返回首次结果
      final replay = await capture.answer(
        challengeId: challenge.challengeId,
        requestId: correctRequest,
        optionId: 'A',
      );
      expect(replay.captureRecordId, correct.captureRecordId);

      // 同一 requestId 不同内容 → 40902
      await expectLater(
        capture.answer(
          challengeId: challenge.challengeId,
          requestId: correctRequest,
          optionId: wrongOption.optionId,
        ),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.conflict)
            .having((e) => e.code, 'code', 40902)),
      );

      final status = await capture.status(challengeId: challenge.challengeId);
      expect(status.status, ChallengeStatusKind.captured);
      expect(status.captureRecordId, correct.captureRecordId);

      final summary = await collection.summary();
      expect(summary.captureCount, greaterThanOrEqualTo(1));
      expect(summary.collectedSpeciesCount, greaterThanOrEqualTo(1));
    }, skip: !enabled, timeout: const Timeout(Duration(minutes: 2)));
  });
}
