import 'dart:async';

import 'location_sample.dart';

/// 位置采集端口（design：LocationProviderPort）。
///
/// 旧课堂 Demo 仍用 [../location_provider.dart] 的字符串地点接口，两者并行。
abstract interface class LocationProviderPort {
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
  Stream<LocationSample> get samples;
  Stream<LocationError> get errors;
}
