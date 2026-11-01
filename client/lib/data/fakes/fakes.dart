import '../api/api_failure.dart';
import '../api/auth_api.dart';
import '../api/capture_api.dart';
import '../api/collection_api.dart';
import '../api/study_api.dart';
import '../model/auth_models.dart';
import '../model/capture_models.dart';
import '../model/collection_models.dart';
import '../model/study_models.dart';

/// 端口替身：仅用于测试与本地独立开发，不代表真实后端行为。
/// 页面使用 Fake 时必须在界面上标注“模拟数据”。

typedef AnswerCall = ({String challengeId, String requestId, String optionId});

class FakeAuthApi implements AuthApi {
  FakeAuthApi({
    UserView? user,
    this.token = 'fake-token',
    this.failure,
    DateTime? expiresAt,
  })  : user = user ??
            const UserView(
              userId: '11111111-1111-4111-8111-111111111111',
              username: 'campus_demo',
              nickname: '校园同学',
            ),
        expiresAt = expiresAt ?? DateTime.utc(2030, 1, 1);

  final UserView user;
  final String token;
  final DateTime expiresAt;
  ApiFailure? failure;

  final List<String> calls = <String>[];

  @override
  Future<UserView> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    calls.add('register:$username');
    if (failure != null) throw failure!;
    return user;
  }

  @override
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    calls.add('login:$username');
    if (failure != null) throw failure!;
    return LoginResult(token: token, expiresAt: expiresAt, user: user);
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    if (failure != null) throw failure!;
  }

  @override
  Future<UserView> me() async {
    calls.add('me');
    if (failure != null) throw failure!;
    return user;
  }
}

class FakeCaptureApi implements CaptureApi {
  FakeCaptureApi({
    this.challengeResponse,
    this.spawnResponse,
    this.defaultAnswer,
    this.defaultStatus,
    this.failure,
  });

  final ChallengeView? challengeResponse;
  final SpawnView? spawnResponse;

  /// 按顺序消费；元素是 CaptureResult 或 ApiFailure。为空时用 [defaultAnswer]。
  final List<Object> answerQueue = <Object>[];

  /// 按顺序消费；元素是 ChallengeStatus 或 ApiFailure。为空时用 [defaultStatus]。
  final List<Object> statusQueue = <Object>[];

  final CaptureResult? defaultAnswer;
  final ChallengeStatus? defaultStatus;
  ApiFailure? failure;

  final List<AnswerCall> answerCalls = <AnswerCall>[];
  final List<String> statusCalls = <String>[];
  int challengeCalls = 0;

  @override
  Future<SpawnView> createDevSpawn({
    required String regionId,
    required String speciesId,
  }) async {
    if (failure != null) throw failure!;
    final spawn = spawnResponse;
    if (spawn == null) throw StateError('FakeCaptureApi 未配置 spawnResponse');
    return spawn;
  }

  @override
  Future<ChallengeView> challenge({required String spawnId}) async {
    challengeCalls++;
    if (failure != null) throw failure!;
    final response = challengeResponse;
    if (response == null) throw StateError('FakeCaptureApi 未配置 challengeResponse');
    return response;
  }

  @override
  Future<CaptureResult> answer({
    required String challengeId,
    required String requestId,
    required String optionId,
  }) async {
    answerCalls.add((
      challengeId: challengeId,
      requestId: requestId,
      optionId: optionId,
    ));
    if (failure != null) throw failure!;
    final next = answerQueue.isEmpty ? null : answerQueue.removeAt(0);
    if (next is ApiFailure) throw next;
    if (next is CaptureResult) return next;
    final fallback = defaultAnswer;
    if (fallback == null) throw StateError('FakeCaptureApi 未配置 answer 响应');
    return fallback;
  }

  @override
  Future<ChallengeStatus> status({required String challengeId}) async {
    statusCalls.add(challengeId);
    if (failure != null) throw failure!;
    final next = statusQueue.isEmpty ? null : statusQueue.removeAt(0);
    if (next is ApiFailure) throw next;
    if (next is ChallengeStatus) return next;
    final fallback = defaultStatus;
    if (fallback == null) throw StateError('FakeCaptureApi 未配置 status 响应');
    return fallback;
  }
}

class FakeCollectionApi implements CollectionApi {
  FakeCollectionApi({this.summaryResponse, this.failure});

  CollectionSummary? summaryResponse;
  ApiFailure? failure;
  int calls = 0;

  @override
  Future<CollectionSummary> summary() async {
    calls++;
    if (failure != null) throw failure!;
    final response = summaryResponse;
    if (response == null) throw StateError('FakeCollectionApi 未配置 summaryResponse');
    return response;
  }
}

class FakeStudyApi implements StudyApi {
  FakeStudyApi({this.task, this.failure});

  TaskSnapshot? task;
  ApiFailure? failure;
  final List<String> calls = <String>[];

  @override
  Future<TaskSnapshot> createTask({
    required String regionId,
    required String requestId,
    required String locationSource,
  }) async {
    calls.add('create:$requestId');
    if (failure != null) throw failure!;
    return _requireTask();
  }

  @override
  Future<TaskSnapshot> uploadSample({
    required String taskId,
    required LocationSampleDto sample,
  }) async {
    calls.add('sample:${sample.sampleId}');
    if (failure != null) throw failure!;
    return _requireTask();
  }

  @override
  Future<TaskSnapshot?> getCurrent() async {
    calls.add('current');
    if (failure != null) throw failure!;
    return task;
  }

  @override
  Future<TaskSnapshot> endTask({
    required String taskId,
    required String requestId,
  }) async {
    calls.add('end:$requestId');
    if (failure != null) throw failure!;
    return _requireTask();
  }

  TaskSnapshot _requireTask() {
    final current = task;
    if (current == null) throw StateError('FakeStudyApi 未配置 task');
    return current;
  }
}
