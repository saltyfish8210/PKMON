import 'dart:async';

import 'location_sample.dart';

/// 位置采集端口（design：LocationProviderPort）。
///
/// 旧课堂 Demo 仍用 [../location_provider.dart] 的字符串地点接口，两者并行。
abstract interface class LocationProviderPort {
  Future<void> start();
  Future<void> stop();
  Stream<LocationSample> get samples;
  Stream<LocationError> get errors;
}

/// 真实 GPS 占位：依赖 geolocator/permission_handler（由余星晨合入 pubspec 后实现）。
class RealLocationProvider implements LocationProviderPort {
  final _errors = StreamController<LocationError>.broadcast();

  @override
  Stream<LocationSample> get samples => const Stream.empty();

  @override
  Stream<LocationError> get errors => _errors.stream;

  @override
  Future<void> start() async {
    _errors.add(const LocationError(
      code: 'NOT_IMPLEMENTED',
      message: 'RealLocationProvider 未实现：等待 permission_handler/geolocator 依赖合入',
    ));
  }

  @override
  Future<void> stop() async {}
}
