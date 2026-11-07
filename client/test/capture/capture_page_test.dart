import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/fakes/fakes.dart';
import 'package:pkmon_app/data/model/capture_models.dart';
import 'package:pkmon_app/data/model/collection_models.dart';
import 'package:pkmon_app/features/capture/capture_controller.dart';
import 'package:pkmon_app/features/capture/capture_page.dart';

ChallengeView makeChallenge({String? sourceType = 'DEV_SIMULATED'}) =>
    ChallengeView(
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
      sourceType: sourceType,
    );

CaptureResult correctResult() => const CaptureResult(
      challengeId: 'c1',
      requestId: 'ignored',
      result: AnswerResult.correct,
      speciesId: 'siege_lion',
      captureRecordId: 'record-1',
    );

FakeCollectionApi makeCollection() => FakeCollectionApi(
      summaryResponse: const CollectionSummary(
        collectedSpeciesCount: 1,
        totalSpeciesCount: 3,
        captureCount: 1,
      ),
    );

Future<void> pumpPage(WidgetTester tester, CaptureController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CapturePage(spawnId: 's1', controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('加载成功显示题干、选项与模拟来源标注', (tester) async {
    final controller = CaptureController(
      captureApi: FakeCaptureApi(challengeResponse: makeChallenge()),
      collectionApi: makeCollection(),
      newRequestId: () => 'req-1',
    );
    await pumpPage(tester, controller);

    expect(find.textContaining('hello world'), findsWidgets);
    expect(find.text('A  hello world'), findsOneWidget);
    expect(find.textContaining('本次使用模拟位置'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('答对显示成功态，并可进入收藏概览', (tester) async {
    final controller = CaptureController(
      captureApi: FakeCaptureApi(
        challengeResponse: makeChallenge(),
        defaultAnswer: correctResult(),
      ),
      collectionApi: makeCollection(),
      newRequestId: () => 'req-1',
    );
    await pumpPage(tester, controller);

    await tester.tap(find.text('A  hello world'));
    await tester.pumpAndSettle();
    expect(find.text('成为伙伴了！'), findsOneWidget);
    expect(find.textContaining('已收集 1 / 3 种'), findsOneWidget);

    await tester.tap(find.text('查看收藏'));
    await tester.pumpAndSettle();
    expect(find.text('收藏概览'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('答错后仍可重新作答', (tester) async {
    final fake = FakeCaptureApi(challengeResponse: makeChallenge())
      ..answerQueue.add(const CaptureResult(
        challengeId: 'c1',
        requestId: 'ignored',
        result: AnswerResult.wrong,
        speciesId: 'siege_lion',
      ));
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-${fake.answerCalls.length}',
    );
    await pumpPage(tester, controller);

    await tester.tap(find.text('A  hello world'));
    await tester.pumpAndSettle();
    expect(find.textContaining('这次没有答对'), findsOneWidget);
    expect(find.text('A  hello world'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('过期显示重新遭遇', (tester) async {
    final fake = FakeCaptureApi(challengeResponse: makeChallenge())
      ..answerQueue.add(const ApiFailure(FailureKind.expired, '已过期', code: 41001));
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-1',
    );
    await pumpPage(tester, controller);

    await tester.tap(find.text('A  hello world'));
    await tester.pumpAndSettle();
    expect(find.text('挑战已过期'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('超时且查询失败时进入结果待确认', (tester) async {
    final fake = FakeCaptureApi(challengeResponse: makeChallenge())
      ..answerQueue.add(const ApiFailure(FailureKind.timeout, '超时'))
      ..statusQueue.add(const ApiFailure(FailureKind.network, '断网'));
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-1',
    );
    await pumpPage(tester, controller);

    await tester.tap(find.text('A  hello world'));
    await tester.pumpAndSettle();
    expect(find.text('结果待确认'), findsOneWidget);
    expect(find.text('重新确认'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('取题失败可重试', (tester) async {
    final fake = FakeCaptureApi(challengeResponse: makeChallenge())
      ..failure = const ApiFailure(FailureKind.serviceUnavailable, '服务未就绪');
    final controller = CaptureController(
      captureApi: fake,
      collectionApi: makeCollection(),
      newRequestId: () => 'req-1',
    );
    await pumpPage(tester, controller);
    expect(find.text('没能完成这次相遇'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    fake.failure = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('A  hello world'), findsOneWidget);
    controller.dispose();
  });
}
