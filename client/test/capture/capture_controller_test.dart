import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/fakes/fakes.dart';
import 'package:pkmon_app/data/model/capture_models.dart';
import 'package:pkmon_app/data/model/collection_models.dart';
import 'package:pkmon_app/features/capture/capture_controller.dart';

ChallengeView makeChallenge() => ChallengeView(
      challengeId: 'c1',
      spawnId: 's1',
      speciesId: 'siege_lion',
      speciesName: '攻城狮',
      questionId: 'q1',
      questionText: '执行 print("hello world") 之后，控制台会输出什么？',
      options: const <OptionView>[
        OptionView(optionId: 'A', text: 'hello world'),
        OptionView(optionId: 'B', text: '程序报错'),
      ],
      expiresAt: DateTime.utc(2030, 1, 1),
    );

CaptureResult correctResult({String recordId = 'record-1'}) => CaptureResult(
      challengeId: 'c1',
      requestId: 'ignored',
      result: AnswerResult.correct,
      speciesId: 'siege_lion',
      captureRecordId: recordId,
    );

CaptureResult wrongResult() => const CaptureResult(
      challengeId: 'c1',
      requestId: 'ignored',
      result: AnswerResult.wrong,
      speciesId: 'siege_lion',
    );

ChallengeStatus capturedStatus({String recordId = 'record-2'}) => ChallengeStatus(
      challengeId: 'c1',
      status: ChallengeStatusKind.captured,
      captureRecordId: recordId,
      expiresAt: DateTime.utc(2030, 1, 1),
    );

ChallengeStatus openStatus() => ChallengeStatus(
      challengeId: 'c1',
      status: ChallengeStatusKind.open,
      expiresAt: DateTime.utc(2030, 1, 1),
    );

FakeCollectionApi makeCollection() => FakeCollectionApi(
      summaryResponse: const CollectionSummary(
        collectedSpeciesCount: 1,
        totalSpeciesCount: 3,
        captureCount: 1,
      ),
    );

void main() {
  test('load 成功进入 Ready', () async {
    final controller = CaptureController(
      captureApi: FakeCaptureApi(challengeResponse: makeChallenge()),
      collectionApi: makeCollection(),
      newRequestId: () => 'req-fixed',
    );
    await controller.load('s1');
    expect(controller.state.value, isA<CaptureReady>());
    controller.dispose();
  });

  test('答对进入 Captured 并刷新概览', () async {
    final collection = makeCollection();
    final controller = CaptureController(
      captureApi: FakeCaptureApi(
        challengeResponse: makeChallenge(),
        defaultAnswer: correctResult(),
      ),
      collectionApi: collection,
      newRequestId: () => 'req-1',
    );

    await controller.load('s1');
    await controller.submit('A');

    final state = controller.state.value;
    expect(state, isA<CaptureCaptured>());
    expect((state as CaptureCaptured).captureRecordId, 'record-1');
    expect(state.summary?.captureCount, 1);
    expect(collection.calls, 1);
    controller.dispose();
  });

  test('答错回到 Ready，重新作答生成新 requestId', () async {
    final fake = FakeCaptureApi(
      challengeResponse: makeChallenge(),
      defaultAnswer: correctResult(),
    )..answerQueue.addAll(<Object>[wrongResult(), correctResult()]);
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () {
        fake.challengeCalls; // 保持闭包无副作用
        return 'req-${fake.answerCalls.length}';
      },
    );

    await controller.load('s1');
    await controller.submit('A');
    expect(controller.state.value, isA<CaptureReady>());
    expect((controller.state.value as CaptureReady).lastResultWasWrong, isTrue);

    await controller.submit('B');
    expect(controller.state.value, isA<CaptureCaptured>());
    expect(fake.answerCalls.length, 2);
    expect(fake.answerCalls[0].requestId, isNot(fake.answerCalls[1].requestId));
    controller.dispose();
  });

  test('超时后查询 CAPTURED：直接成功，不重发作答', () async {
    final fake = FakeCaptureApi(
      challengeResponse: makeChallenge(),
      defaultAnswer: correctResult(),
    )
      ..answerQueue.add(const ApiFailure(FailureKind.timeout, '超时'))
      ..statusQueue.add(capturedStatus());
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-timeout',
    );

    await controller.load('s1');
    await controller.submit('A');

    expect(controller.state.value, isA<CaptureCaptured>());
    expect((controller.state.value as CaptureCaptured).captureRecordId, 'record-2');
    expect(fake.answerCalls.length, 1);
    expect(fake.statusCalls.length, 1);
    controller.dispose();
  });

  test('超时后查询 OPEN：用原 requestId 与 optionId 重试', () async {
    final fake = FakeCaptureApi(
      challengeResponse: makeChallenge(),
      defaultAnswer: correctResult(),
    )
      ..answerQueue.addAll(<Object>[
        const ApiFailure(FailureKind.timeout, '超时'),
        correctResult(),
      ])
      ..statusQueue.add(openStatus());
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-retry',
    );

    await controller.load('s1');
    await controller.submit('A');

    expect(controller.state.value, isA<CaptureCaptured>());
    expect(fake.answerCalls.length, 2);
    expect(fake.answerCalls[0].requestId, fake.answerCalls[1].requestId);
    expect(fake.answerCalls[0].optionId, fake.answerCalls[1].optionId);
    expect(fake.answerCalls[0].requestId, 'req-retry');
    controller.dispose();
  });

  test('过期进入 Expired', () async {
    final fake = FakeCaptureApi(
      challengeResponse: makeChallenge(),
      defaultAnswer: correctResult(),
    )..answerQueue.add(const ApiFailure(FailureKind.expired, '已过期', code: 41001));
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-expired',
    );

    await controller.load('s1');
    await controller.submit('A');

    expect(controller.state.value, isA<CaptureExpired>());
    controller.dispose();
  });

  test('提交中重复点击只发出一次作答', () async {
    final fake = FakeCaptureApi(
      challengeResponse: makeChallenge(),
      defaultAnswer: correctResult(),
    );
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-once',
    );

    await controller.load('s1');
    final first = controller.submit('A');
    final second = controller.submit('B');
    await Future.wait(<Future<void>>[first, second]);

    expect(fake.answerCalls.length, 1);
    controller.dispose();
  });

  test('取题失败进入 Failed 且可重试', () async {
    final fake = FakeCaptureApi(
      challengeResponse: makeChallenge(),
      defaultAnswer: correctResult(),
    )..failure = const ApiFailure(FailureKind.serviceUnavailable, '服务未就绪');
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-load',
    );

    await controller.load('s1');
    expect(controller.state.value, isA<CaptureFailed>());

    fake.failure = null;
    await controller.retry();
    expect(controller.state.value, isA<CaptureReady>());
    controller.dispose();
  });
}
