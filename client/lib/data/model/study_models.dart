import '../api/api_failure.dart';
import 'parsing.dart';

const _taskStatuses = <String>{
  'WAITING',
  'DWELLING',
  'PAUSED',
  'TRIGGERED',
  'ENDED',
};

/// 自习任务快照。状态只能由服务端返回，客户端不得本地改为 TRIGGERED。
class TaskSnapshot {
  const TaskSnapshot({
    required this.taskId,
    required this.regionId,
    required this.status,
    required this.effectiveSeconds,
    required this.requiredSeconds,
    required this.serverTime,
    this.pauseReason,
    this.spawnId,
    this.sampleAccepted,
    this.rejectionReason,
  });

  factory TaskSnapshot.fromJson(Map<String, dynamic> json) {
    final status = requireString(json, 'status');
    if (!_taskStatuses.contains(status)) {
      throw ApiFailure.protocol('未知任务状态 $status');
    }
    return TaskSnapshot(
      taskId: requireString(json, 'taskId'),
      regionId: requireString(json, 'regionId'),
      status: status,
      pauseReason: optionalString(json, 'pauseReason'),
      effectiveSeconds: requireInt(json, 'effectiveSeconds'),
      requiredSeconds: requireInt(json, 'requiredSeconds'),
      spawnId: optionalString(json, 'spawnId'),
      serverTime: requireUtcTime(json, 'serverTime'),
      sampleAccepted: optionalBool(json, 'sampleAccepted'),
      rejectionReason: optionalString(json, 'rejectionReason'),
    );
  }

  /// `GET /study/tasks/current` 的 data.task 可为 null。
  static TaskSnapshot? fromCurrentEnvelope(Map<String, dynamic> data) {
    final task = data['task'];
    if (task == null) return null;
    return TaskSnapshot.fromJson(asJsonMap(task, 'task'));
  }

  final String taskId;
  final String regionId;
  final String status;
  final String? pauseReason;
  final int effectiveSeconds;
  final int requiredSeconds;
  final String? spawnId;
  final DateTime serverTime;
  final bool? sampleAccepted;
  final String? rejectionReason;
}

/// 上传给服务端的位置样本（只含上传字段，不含本地定位实现）。
class LocationSampleDto {
  const LocationSampleDto({
    required this.sampleId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.sampledAt,
    required this.coordinateSystem,
    required this.source,
  });

  final String sampleId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime sampledAt;
  final String coordinateSystem;
  final String source;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sampleId': sampleId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'sampledAt': sampledAt.toUtc().toIso8601String(),
        'coordinateSystem': coordinateSystem,
        'source': source,
      };
}
