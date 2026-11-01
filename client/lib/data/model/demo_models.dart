import '../api/api_failure.dart';
import 'capture_models.dart';
import 'parsing.dart';

/// 旧演示会话状态（/api/v1/demo/state）。
class DemoState {
  const DemoState({
    required this.nearby,
    required this.captured,
    required this.count,
    required this.totalSpecies,
  });

  factory DemoState.fromJson(Map<String, dynamic> json) => DemoState(
        nearby: requireBool(json, 'nearby'),
        captured: requireBool(json, 'captured'),
        count: requireInt(json, 'count'),
        totalSpecies: requireInt(json, 'totalSpecies'),
      );

  final bool nearby;
  final bool captured;
  final int count;
  final int totalSpecies;
}

class LegacyOption {
  const LegacyOption({required this.id, required this.text});

  factory LegacyOption.fromJson(Map<String, dynamic> json) => LegacyOption(
        id: requireString(json, 'id'),
        text: requireString(json, 'text'),
      );

  final String id;
  final String text;
}

/// 旧演示题目：name / question / options[].id，仅用于旧页面与课堂演示。
class LegacyChallenge {
  const LegacyChallenge({
    required this.challengeId,
    required this.spawnId,
    required this.name,
    required this.question,
    required this.options,
    required this.source,
  });

  factory LegacyChallenge.fromJson(Map<String, dynamic> json) {
    final rawOptions = asJsonList(json['options'], 'options');
    return LegacyChallenge(
      challengeId: requireString(json, 'challengeId'),
      spawnId: requireString(json, 'spawnId'),
      name: requireString(json, 'name'),
      question: requireString(json, 'question'),
      options: rawOptions
          .map((item) => LegacyOption.fromJson(asJsonMap(item, 'options[]')))
          .toList(growable: false),
      source: optionalString(json, 'source') ?? '',
    );
  }

  final String challengeId;
  final String spawnId;
  final String name;
  final String question;
  final List<LegacyOption> options;
  final String source;

  /// 旧字段只在这里转换一次；页面与控制器不出现旧字段名。
  ChallengeView toChallengeView() => ChallengeView(
        challengeId: challengeId,
        spawnId: spawnId,
        speciesId: 'siege_lion',
        speciesName: name,
        questionId: 'demo_question',
        questionText: question,
        options: options
            .map((option) => OptionView(optionId: option.id, text: option.text))
            .toList(growable: false),
        // 旧接口不返回有效期；演示页只做展示，给一个固定展示窗口。
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        sourceType: 'DEMO',
      );
}

/// 旧演示作答：success / message / count。没有 captureRecordId，
/// 因此不得当作正式捕获成功证据。
class LegacyAnswer {
  const LegacyAnswer({
    required this.success,
    required this.message,
    required this.count,
  });

  factory LegacyAnswer.fromJson(Map<String, dynamic> json) => LegacyAnswer(
        success: requireBool(json, 'success'),
        message: optionalString(json, 'message') ?? '',
        count: requireInt(json, 'count'),
      );

  final bool success;
  final String message;
  final int count;

  CaptureResult toCaptureResult(String challengeId) => CaptureResult(
        challengeId: challengeId,
        requestId: '',
        result: success ? AnswerResult.correct : AnswerResult.wrong,
        speciesId: 'siege_lion',
        // 旧接口没有收录标识：即使 success，也不构成正式收录证据。
        captureRecordId: null,
      );
}

/// 演示接口返回但不应被 UI 直接使用的空响应占位。
Map<String, dynamic> ensureObject(Object? value, String field) =>
    asJsonMap(value, field);

/// 供 DemoApi 使用的错误构造（保持与正式接口一致的 kind）。
ApiFailure demoUnavailable() =>
    ApiFailure(FailureKind.serviceUnavailable, '演示接口不可用');
