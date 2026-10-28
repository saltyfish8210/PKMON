import '../../core/location/location_sample.dart';

/// 自习任务快照（与 design TaskSnapshot 对齐）。
class TaskSnapshot {
  const TaskSnapshot({
    required this.taskId,
    required this.regionId,
    required this.status,
    this.pauseReason,
    required this.effectiveSeconds,
    required this.requiredSeconds,
    this.spawnId,
    required this.serverTime,
    this.sampleAccepted,
    this.rejectionReason,
  });

  final String taskId;
  final String regionId;

  /// WAITING | DWELLING | PAUSED | TRIGGERED | ENDED
  final String status;
  final String? pauseReason;
  final int effectiveSeconds;
  final int requiredSeconds;
  final String? spawnId;
  final DateTime serverTime;
  final bool? sampleAccepted;
  final String? rejectionReason;

  TaskSnapshot copyWith({
    String? status,
    String? pauseReason,
    int? effectiveSeconds,
    String? spawnId,
    DateTime? serverTime,
    bool? sampleAccepted,
    String? rejectionReason,
    bool clearPauseReason = false,
    bool clearSpawnId = false,
  }) {
    return TaskSnapshot(
      taskId: taskId,
      regionId: regionId,
      status: status ?? this.status,
      pauseReason: clearPauseReason ? null : (pauseReason ?? this.pauseReason),
      effectiveSeconds: effectiveSeconds ?? this.effectiveSeconds,
      requiredSeconds: requiredSeconds,
      spawnId: clearSpawnId ? null : (spawnId ?? this.spawnId),
      serverTime: serverTime ?? this.serverTime,
      sampleAccepted: sampleAccepted ?? this.sampleAccepted,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

abstract interface class StudyApi {
  Future<TaskSnapshot> createTask({
    required String regionId,
    required String requestId,
    required String locationSource,
  });

  Future<TaskSnapshot> uploadSample({
    required String taskId,
    required LocationSample sample,
  });

  Future<TaskSnapshot?> getCurrent();

  Future<TaskSnapshot> endTask({
    required String taskId,
    required String requestId,
  });
}

/// 真实 HTTP 占位：任务路由尚未由董欣毓实现。
class HttpStudyApi implements StudyApi {
  @override
  Future<TaskSnapshot> createTask({
    required String regionId,
    required String requestId,
    required String locationSource,
  }) {
    throw UnsupportedError('HttpStudyApi 未实现：等待 /api/v1/study/tasks');
  }

  @override
  Future<TaskSnapshot> uploadSample({
    required String taskId,
    required LocationSample sample,
  }) {
    throw UnsupportedError('HttpStudyApi 未实现：等待 /api/v1/study/tasks/{id}/samples');
  }

  @override
  Future<TaskSnapshot?> getCurrent() {
    throw UnsupportedError('HttpStudyApi 未实现：等待 /api/v1/study/tasks/current');
  }

  @override
  Future<TaskSnapshot> endTask({
    required String taskId,
    required String requestId,
  }) {
    throw UnsupportedError('HttpStudyApi 未实现：等待 /api/v1/study/tasks/{id}/end');
  }
}
