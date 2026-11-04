import '../../data/model/study_models.dart';
export '../../data/api/study_api.dart';
export '../../data/model/study_models.dart' show TaskSnapshot;

extension FakeSnapshotUpdate on TaskSnapshot {
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
