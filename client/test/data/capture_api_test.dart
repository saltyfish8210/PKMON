import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/api/capture_api.dart';
import 'package:pkmon_app/data/model/capture_models.dart';

import 'mock_client_fixture.dart';
import 'test_support.dart';

void main() {
  group('HttpCaptureApi', () {
    test('取题解析统一字段', () async {
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.challenge()),
      );
      final view = await api.challenge(spawnId: 'spawn-1');
      expect(view.speciesName, '攻城狮');
      expect(view.questionText, contains('hello world'));
      expect(view.options.length, 3);
      expect(view.optionById('A')?.text, 'hello world');
    });

    test('题目响应含答案字段时拒绝', () async {
      final data = Map<String, dynamic>.from(
        fixture('07-challenge.json')['data'] as Map<String, dynamic>,
      )..['correctOptionId'] = 'A';
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.envelopeOf(data)),
      );
      await expectLater(
        api.challenge(spawnId: 'spawn-1'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.protocol)),
      );
    });

    test('答对必须带 captureRecordId', () async {
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.answerCorrect()),
      );
      final result = await api.answer(
        challengeId: 'c1',
        requestId: 'r1',
        optionId: 'A',
      );
      expect(result.captured, isTrue);
      expect(result.captureRecordId, isNotNull);
    });

    test('CORRECT 缺记录号视为契约违约', () async {
      final data = Map<String, dynamic>.from(
        fixture('08-answer.json')['data'] as Map<String, dynamic>,
      )..['captureRecordId'] = null;
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.envelopeOf(data)),
      );
      await expectLater(
        api.answer(challengeId: 'c1', requestId: 'r1', optionId: 'A'),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.protocol)),
      );
    });

    test('答错不产生收录', () async {
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.answerWrong()),
      );
      final result = await api.answer(
        challengeId: 'c1',
        requestId: 'r2',
        optionId: 'B',
      );
      expect(result.captured, isFalse);
      expect(result.captureRecordId, isNull);
    });

    test('状态查询映射 CAPTURED 与 lastAttempt', () async {
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.statusCaptured()),
      );
      final status = await api.status(challengeId: 'c1');
      expect(status.status, ChallengeStatusKind.captured);
      expect(status.captureRecordId, isNotNull);
      expect(status.lastAttempt?.result, AnswerResult.correct);
    });

    test('状态查询允许 lastAttempt 为空', () async {
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.statusOpen()),
      );
      final status = await api.status(challengeId: 'c1');
      expect(status.status, ChallengeStatusKind.open);
      expect(status.lastAttempt, isNull);
    });

    test('状态查询映射 EXPIRED', () async {
      final api = HttpCaptureApi(
        clientWith(MockClientFixture.statusExpired()),
      );
      final status = await api.status(challengeId: 'c1');
      expect(status.status, ChallengeStatusKind.expired);
    });
  });
}
