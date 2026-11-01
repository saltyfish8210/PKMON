import '../../core/location/location_sample.dart';
import 'study_api.dart';

/// 内存 Fake：演示五态。必须在 UI 标注「模拟」，不得伪装真实到场。
class FakeStudyApi implements StudyApi {
  FakeStudyApi({this.requiredSeconds = 60, this.dwellSamplesToTrigger = 3});

  final int requiredSeconds;

  /// 连续合格样本数达到该值后进入 TRIGGERED（骨架演示用，非真实驻留规则）。
  final int dwellSamplesToTrigger;

  TaskSnapshot? _current;
  final Set<String> _seenSampleIds = {};
  int _acceptedCount = 0;
  String? _lastCreateRequestId;
  String? _forcedStatus;

  /// 测试/调试：强制下一拍状态（WAITING/DWELLING/PAUSED/TRIGGERED/ENDED）。
  void debugForceStatus(String? status) => _forcedStatus = status;

  void reset() {
    _current = null;
    _seenSampleIds.clear();
    _acceptedCount = 0;
    _lastCreateRequestId = null;
    _forcedStatus = null;
  }

  @override
  Future<TaskSnapshot> createTask({
    required String regionId,
    required String requestId,
    required String locationSource,
  }) async {
    if (_lastCreateRequestId == requestId && _current != null) {
      return _current!;
    }
    _lastCreateRequestId = requestId;
    _seenSampleIds.clear();
    _acceptedCount = 0;
    _forcedStatus = null;
    _current = TaskSnapshot(
      taskId: 'fake-task-$requestId',
      regionId: regionId,
      status: 'WAITING',
      effectiveSeconds: 0,
      requiredSeconds: requiredSeconds,
      serverTime: DateTime.now().toUtc(),
    );
    return _current!;
  }

  @override
  Future<TaskSnapshot> uploadSample({
    required String taskId,
    required LocationSample sample,
  }) async {
    final cur = _current;
    if (cur == null || cur.taskId != taskId) {
      throw StateError('任务不存在或不属于当前会话（Fake）');
    }
    if (cur.status == 'ENDED' || cur.status == 'TRIGGERED') {
      return cur.copyWith(
        sampleAccepted: false,
        rejectionReason: 'task_closed',
        serverTime: DateTime.now().toUtc(),
      );
    }

    if (_seenSampleIds.contains(sample.sampleId)) {
      return cur.copyWith(
        sampleAccepted: false,
        rejectionReason: 'duplicate_sampleId',
        serverTime: DateTime.now().toUtc(),
      );
    }
    if (sample.accuracyMeters > 50) {
      return cur.copyWith(
        sampleAccepted: false,
        rejectionReason: 'accuracy',
        serverTime: DateTime.now().toUtc(),
      );
    }
    if (sample.coordinateSystem != 'GCJ02') {
      return cur.copyWith(
        sampleAccepted: false,
        rejectionReason: 'coordinate_system',
        serverTime: DateTime.now().toUtc(),
      );
    }

    _seenSampleIds.add(sample.sampleId);
    _acceptedCount += 1;

    var status = cur.status;
    var pauseReason = cur.pauseReason;
    var effective = cur.effectiveSeconds;
    String? spawnId = cur.spawnId;

    if (_forcedStatus != null) {
      status = _forcedStatus!;
      if (status == 'PAUSED') pauseReason = pauseReason ?? 'NO_SIGNAL';
      if (status == 'TRIGGERED') {
        spawnId ??= 'fake-spawn-$taskId';
        effective = requiredSeconds;
      }
      if (status != 'PAUSED') pauseReason = null;
    } else {
      if (_acceptedCount == 1) {
        status = 'WAITING';
        effective = 0;
      } else if (_acceptedCount < dwellSamplesToTrigger) {
        status = 'DWELLING';
        effective = (_acceptedCount - 1) * 10;
        pauseReason = null;
      } else {
        status = 'TRIGGERED';
        effective = requiredSeconds;
        spawnId = 'fake-spawn-$taskId';
        pauseReason = null;
      }
    }

    _current = cur.copyWith(
      status: status,
      pauseReason: pauseReason,
      clearPauseReason: pauseReason == null,
      effectiveSeconds: effective.clamp(0, requiredSeconds),
      spawnId: spawnId,
      sampleAccepted: true,
      rejectionReason: null,
      serverTime: DateTime.now().toUtc(),
    );
    return _current!;
  }

  @override
  Future<TaskSnapshot?> getCurrent() async => _current;

  @override
  Future<TaskSnapshot> endTask({
    required String taskId,
    required String requestId,
  }) async {
    final cur = _current;
    if (cur == null || cur.taskId != taskId) {
      throw StateError('任务不存在（Fake）');
    }
    _current = cur.copyWith(
      status: 'ENDED',
      clearPauseReason: true,
      serverTime: DateTime.now().toUtc(),
      sampleAccepted: null,
      rejectionReason: null,
    );
    return _current!;
  }
}
