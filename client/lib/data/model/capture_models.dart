import '../api/api_failure.dart';
import 'parsing.dart';

/// 一次遭遇机会。`sourceType` 为 DEV_SIMULATED 时界面必须标注“模拟”。
class SpawnView {
  const SpawnView({
    required this.spawnId,
    required this.regionId,
    required this.speciesId,
    required this.sourceType,
    required this.expiresAt,
  });

  factory SpawnView.fromJson(Map<String, dynamic> json) => SpawnView(
        spawnId: requireString(json, 'spawnId'),
        regionId: requireString(json, 'regionId'),
        speciesId: requireString(json, 'speciesId'),
        sourceType: requireString(json, 'sourceType'),
        expiresAt: requireUtcTime(json, 'expiresAt'),
      );

  final String spawnId;
  final String regionId;
  final String speciesId;
  final String sourceType;
  final DateTime expiresAt;
}

class OptionView {
  const OptionView({required this.optionId, required this.text});

  factory OptionView.fromJson(Map<String, dynamic> json) => OptionView(
        optionId: requireString(json, 'optionId'),
        text: requireString(json, 'text'),
      );

  final String optionId;
  final String text;
}

/// 一道题目的只读视图。解析时拒绝任何答案字段，契约违约按 [FailureKind.protocol] 处理。
class ChallengeView {
  const ChallengeView({
    required this.challengeId,
    required this.spawnId,
    required this.speciesId,
    required this.speciesName,
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.expiresAt,
    this.sourceType,
  });

  factory ChallengeView.fromJson(Map<String, dynamic> json) {
    for (final key in const ['correctOptionId', 'answer', 'correctAnswer']) {
      if (json.containsKey(key)) {
        throw ApiFailure.protocol('题目响应包含答案字段 $key');
      }
    }
    final rawOptions = asJsonList(json['options'], 'options');
    if (rawOptions.length < 2 || rawOptions.length > 4) {
      throw ApiFailure.protocol('选项数量应为 2..4，实际 ${rawOptions.length}');
    }
    return ChallengeView(
      challengeId: requireString(json, 'challengeId'),
      spawnId: requireString(json, 'spawnId'),
      speciesId: requireString(json, 'speciesId'),
      speciesName: requireString(json, 'speciesName'),
      questionId: requireString(json, 'questionId'),
      questionText: requireString(json, 'questionText'),
      options: rawOptions
          .map((item) => OptionView.fromJson(asJsonMap(item, 'options[]')))
          .toList(growable: false),
      expiresAt: requireUtcTime(json, 'expiresAt'),
      sourceType: optionalString(json, 'sourceType'),
    );
  }

  final String challengeId;
  final String spawnId;
  final String speciesId;
  final String speciesName;
  final String questionId;
  final String questionText;
  final List<OptionView> options;
  final DateTime expiresAt;

  /// 旧演示适配时写入 DEMO；正式接口通常为空。
  final String? sourceType;

  bool get isSimulated => sourceType == 'DEV_SIMULATED' || sourceType == 'DEMO';

  OptionView? optionById(String optionId) {
    for (final option in options) {
      if (option.optionId == optionId) return option;
    }
    return null;
  }
}

enum AnswerResult {
  correct,
  wrong;

  static AnswerResult parse(String value) => switch (value) {
        'CORRECT' => correct,
        'WRONG' => wrong,
        _ => throw ApiFailure.protocol('未知作答结果 $value'),
      };

  String get wire => this == correct ? 'CORRECT' : 'WRONG';
}

/// 服务端已结算的作答结果。CORRECT 必须带 captureRecordId，否则视为契约违约。
class CaptureResult {
  const CaptureResult({
    required this.challengeId,
    required this.requestId,
    required this.result,
    required this.speciesId,
    this.captureRecordId,
  });

  factory CaptureResult.fromJson(Map<String, dynamic> json) {
    final result = AnswerResult.parse(requireString(json, 'result'));
    final recordId = optionalString(json, 'captureRecordId');
    if (result == AnswerResult.correct && (recordId == null || recordId.isEmpty)) {
      throw ApiFailure.protocol('CORRECT 缺少 captureRecordId');
    }
    return CaptureResult(
      challengeId: requireString(json, 'challengeId'),
      requestId: requireString(json, 'requestId'),
      result: result,
      speciesId: requireString(json, 'speciesId'),
      captureRecordId: recordId,
    );
  }

  final String challengeId;
  final String requestId;
  final AnswerResult result;
  final String speciesId;
  final String? captureRecordId;

  bool get captured => result == AnswerResult.correct && captureRecordId != null;
}

enum ChallengeStatusKind {
  open,
  captured,
  expired;

  static ChallengeStatusKind parse(String value) => switch (value) {
        'OPEN' => open,
        'CAPTURED' => captured,
        'EXPIRED' => expired,
        _ => throw ApiFailure.protocol('未知挑战状态 $value'),
      };
}

class LastAttempt {
  const LastAttempt({
    required this.requestId,
    required this.result,
    this.submittedAt,
  });

  factory LastAttempt.fromJson(Map<String, dynamic> json) => LastAttempt(
        requestId: requireString(json, 'requestId'),
        result: AnswerResult.parse(requireString(json, 'result')),
        submittedAt: optionalUtcTime(json, 'submittedAt'),
      );

  final String requestId;
  final AnswerResult result;
  final DateTime? submittedAt;
}

/// 挑战状态查询结果。用于“结果待确认”时恢复真实状态。
class ChallengeStatus {
  const ChallengeStatus({
    required this.challengeId,
    required this.status,
    required this.expiresAt,
    this.captureRecordId,
    this.lastAttempt,
  });

  factory ChallengeStatus.fromJson(Map<String, dynamic> json) {
    final status = ChallengeStatusKind.parse(requireString(json, 'status'));
    final recordId = optionalString(json, 'captureRecordId');
    if (status == ChallengeStatusKind.captured &&
        (recordId == null || recordId.isEmpty)) {
      throw ApiFailure.protocol('CAPTURED 状态缺少 captureRecordId');
    }
    final rawAttempt = json['lastAttempt'];
    return ChallengeStatus(
      challengeId: requireString(json, 'challengeId'),
      status: status,
      captureRecordId: recordId,
      expiresAt: requireUtcTime(json, 'expiresAt'),
      lastAttempt: rawAttempt == null
          ? null
          : LastAttempt.fromJson(asJsonMap(rawAttempt, 'lastAttempt')),
    );
  }

  final String challengeId;
  final ChallengeStatusKind status;
  final String? captureRecordId;
  final DateTime expiresAt;
  final LastAttempt? lastAttempt;
}
