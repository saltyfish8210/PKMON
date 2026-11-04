import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_provider.dart';
import 'location_sample.dart';

/// Foreground device fixes, timestamped by the platform and kept in WGS84.
class DeviceLocationProvider implements LocationProviderPort {
  final _samples = StreamController<LocationSample>.broadcast();
  final _errors = StreamController<LocationError>.broadcast();
  StreamSubscription<Position>? _positions;
  StreamSubscription<ServiceStatus>? _services;
  int _generation = 0;

  @override
  Stream<LocationSample> get samples => _samples.stream;
  @override
  Stream<LocationError> get errors => _errors.stream;

  @override
  Future<void> start() async {
    final generation = ++_generation;
    await _cancelStreams();
    if (generation != _generation) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('系统定位已关闭，请开启后重试');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw StateError(
        permission == LocationPermission.deniedForever
            ? '请到系统设置中允许本应用使用位置，再返回重试'
            : '定位权限未授予，可授权后重试',
      );
    }
    if (generation != _generation) return;
    _services = Geolocator.getServiceStatusStream().listen(
      (state) {
        if (state == ServiceStatus.disabled && generation == _generation) {
          _fail('系统定位已关闭');
        }
      },
      onError: (Object _) {
        if (generation == _generation) _fail('无法读取定位服务状态');
      },
    );
    _positions =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 3),
          ),
        ).listen(
          (position) {
            if (generation != _generation) return;
            if (position.isMocked) {
              _fail('设备正在提供模拟定位，请改用课堂模拟位置');
              return;
            }
            final when = position.timestamp.toUtc();
            _samples.add(
              LocationSample(
                sampleId: 'gps-${when.microsecondsSinceEpoch}',
                sampledAt: when,
                source: 'GPS',
                latitude: position.latitude,
                longitude: position.longitude,
                accuracyMeters: position.accuracy,
                coordinateSystem: 'WGS84',
              ),
            );
          },
          onError: (Object _) {
            if (generation == _generation) _fail('定位中断，请检查权限和定位服务');
          },
        );
  }

  void _fail(String message) {
    _errors.add(LocationError(code: 'LOCATION', message: message));
    unawaited(stop());
  }

  @override
  Future<void> stop() async {
    ++_generation;
    await _cancelStreams();
  }

  Future<void> _cancelStreams() async {
    final positions = _positions;
    final services = _services;
    _positions = null;
    _services = null;
    await positions?.cancel();
    await services?.cancel();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _samples.close();
    await _errors.close();
  }
}
