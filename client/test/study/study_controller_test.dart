import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/core/location/simulated_location_provider.dart';
import 'package:pkmon_app/features/study/fake_study_api.dart';
import 'package:pkmon_app/features/study/study_controller.dart';

void main() {
  test('Controller 只按 Fake 响应更新，dispose 停止采样', () async {
    final location = SimulatedLocationProvider(
      interval: const Duration(milliseconds: 40),
    );
    final api = FakeStudyApi(dwellSamplesToTrigger: 3);
    final controller = StudyController(api: api, location: location);

    await controller.startStudy();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.view.task, isNotNull);
    expect(controller.view.simulated, isTrue);
    // 状态必须来自 Fake，不能是客户端凭空写的非法值
    expect(
      ['WAITING', 'DWELLING', 'PAUSED', 'TRIGGERED', 'ENDED'],
      contains(controller.view.status),
    );

    await controller.endStudy();
    expect(controller.view.status, 'ENDED');
    expect(location.isRunning, isFalse);

    controller.dispose();
  });
}
