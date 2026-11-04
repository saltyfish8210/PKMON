import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pkmon_app/core/location/device_location_provider.dart';

class TestPositionFeed extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  final fixes = StreamController<Position>.broadcast();
  final services = StreamController<ServiceStatus>.broadcast();
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      fixes.stream;
  @override
  Stream<ServiceStatus> getServiceStatusStream() => services.stream;
}

void main() {
  late TestPositionFeed feed;
  late DeviceLocationProvider provider;
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    feed = TestPositionFeed();
    GeolocatorPlatform.instance = feed;
    provider = DeviceLocationProvider();
  });
  tearDown(() async {
    await provider.dispose();
    await feed.fixes.close();
    await feed.services.close();
    GeolocatorPlatform.instance = original;
  });

  test('拒绝、永久拒绝和服务关闭都不订阅；恢复后可以开始采样', () async {
    for (final p in [
      LocationPermission.denied,
      LocationPermission.deniedForever,
    ]) {
      feed.permission = p;
      await expectLater(provider.start(), throwsStateError);
      expect(feed.fixes.hasListener, isFalse);
    }
    feed.permission = LocationPermission.whileInUse;
    feed.enabled = false;
    await expectLater(provider.start(), throwsStateError);
    feed.enabled = true;
    await provider.start();
    expect(feed.fixes.hasListener, isTrue);
  });

  test('保留设备时刻和WGS84；服务关闭或退出后释放订阅', () async {
    await provider.start();
    final time = DateTime.utc(2026, 11, 4, 11);
    final next = provider.samples.first;
    feed.fixes.add(
      Position(
        longitude: 116,
        latitude: 39,
        timestamp: time,
        accuracy: 8,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    final sample = await next;
    expect(sample.coordinateSystem, 'WGS84');
    expect(sample.sampledAt, time);
    expect(sample.source, 'GPS');
    final issue = provider.errors.first;
    feed.services.add(ServiceStatus.disabled);
    expect((await issue).message, contains('关闭'));
    await Future<void>.delayed(Duration.zero);
    expect(feed.fixes.hasListener, isFalse);
    await provider.start();
    await provider.stop();
    expect(feed.services.hasListener, isFalse);
  });
}
