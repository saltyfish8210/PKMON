import 'dart:async';

import 'package:flutter/foundation.dart';

import 'location_provider.dart';
import 'location_sample.dart';

/// 合成位置流。UI 必须标注「模拟」，不得伪装真实到场。
class SimulatedLocationProvider implements LocationProviderPort {
  SimulatedLocationProvider({
    this.interval = const Duration(seconds: 10),
    this.simulatePermissionDenied = false,
    this.baseLatitude = 39.9925,
    this.baseLongitude = 116.326,
  });

  /// 采样间隔；测试可传入更短时长。
  final Duration interval;

  /// 为 true 时 start 只发权限错误，不推样本。
  final bool simulatePermissionDenied;

  final double baseLatitude;
  final double baseLongitude;

  final _samples = StreamController<LocationSample>.broadcast();
  final _errors = StreamController<LocationError>.broadcast();
  Timer? _timer;
  int _seq = 0;
  bool _running = false;

  @override
  Stream<LocationSample> get samples => _samples.stream;

  @override
  Stream<LocationError> get errors => _errors.stream;

  bool get isRunning => _running;

  @override
  Future<void> start() async {
    if (_running) return;
    if (simulatePermissionDenied) {
      _errors.add(const LocationError(
        code: 'PERMISSION_DENIED',
        message: '模拟：定位权限被拒绝',
      ));
      return;
    }
    _running = true;
    _emit();
    _timer = Timer.periodic(interval, (_) => _emit());
  }

  void _emit() {
    if (!_running || _samples.isClosed) return;
    _seq += 1;
    final now = DateTime.now().toUtc();
    _samples.add(LocationSample(
      sampleId: 'sim-${now.microsecondsSinceEpoch}-$_seq',
      latitude: baseLatitude,
      longitude: baseLongitude,
      accuracyMeters: 12,
      sampledAt: now,
      coordinateSystem: 'GCJ02',
      source: 'SIMULATED',
    ));
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  /// 测试或页面销毁时关闭流。
  @mustCallSuper
  Future<void> dispose() async {
    await stop();
    await _samples.close();
    await _errors.close();
  }
}
