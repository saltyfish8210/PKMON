import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/core/location/location_sample.dart';
import 'package:pkmon_app/core/location/simulated_location_provider.dart';

void main() {
  test('合成流推送 SIMULATED/GCJ02 样本，stop 后不再推送', () async {
    final provider = SimulatedLocationProvider(
      interval: const Duration(milliseconds: 50),
    );
    final received = <LocationSample>[];
    final sub = provider.samples.listen(received.add);

    await provider.start();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await provider.stop();
    final countAfterStop = received.length;
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(countAfterStop, greaterThanOrEqualTo(2));
    expect(received.length, countAfterStop);
    expect(received.first.source, 'SIMULATED');
    expect(received.first.coordinateSystem, 'GCJ02');

    await sub.cancel();
    await provider.dispose();
  });

  test('simulatePermissionDenied 时只发错误不发样本', () async {
    final provider = SimulatedLocationProvider(simulatePermissionDenied: true);
    final errors = <LocationError>[];
    final samples = <LocationSample>[];
    final eSub = provider.errors.listen(errors.add);
    final sSub = provider.samples.listen(samples.add);

    await provider.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(errors, isNotEmpty);
    expect(errors.first.code, 'PERMISSION_DENIED');
    expect(samples, isEmpty);

    await eSub.cancel();
    await sSub.cancel();
    await provider.dispose();
  });
}
