/// 单次位置样本。字段与 design/interfaces.json 上传契约同构。
class LocationSample {
  const LocationSample({
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

  /// UTC
  final DateTime sampledAt;

  /// 上传契约期望 GCJ02；未知时保留原标签，禁止改标签冒充。
  final String coordinateSystem;

  /// GPS | SIMULATED
  final String source;

  Map<String, Object?> toJson() => {
        'sampleId': sampleId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'sampledAt': sampledAt.toUtc().toIso8601String(),
        'coordinateSystem': coordinateSystem,
        'source': source,
      };
}

/// 定位错误通道。
class LocationError {
  const LocationError({required this.code, required this.message});

  /// PERMISSION_DENIED | SERVICE_DISABLED | UNKNOWN | NOT_IMPLEMENTED
  final String code;
  final String message;
}
