import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/core/location/location_sample.dart';
import 'package:pkmon_app/features/study/fake_study_api.dart';

LocationSample _sample(String id) => LocationSample(
      sampleId: id,
      latitude: 39.99,
      longitude: 116.32,
      accuracyMeters: 10,
      sampledAt: DateTime.now().toUtc(),
      coordinateSystem: 'GCJ02',
      source: 'SIMULATED',
    );

void main() {
  test('Fake 五态：WAITING→DWELLING→TRIGGERED，重复 sampleId 拒收', () async {
    final api = FakeStudyApi(dwellSamplesToTrigger: 3, requiredSeconds: 60);
    final created = await api.createTask(
      regionId: 'library_entrance',
      requestId: 'r1',
      locationSource: 'SIMULATED',
    );
    expect(created.status, 'WAITING');

    final s1 = await api.uploadSample(taskId: created.taskId, sample: _sample('a'));
    expect(s1.status, 'WAITING');
    expect(s1.sampleAccepted, isTrue);

    final s2 = await api.uploadSample(taskId: created.taskId, sample: _sample('b'));
    expect(s2.status, 'DWELLING');

    final dup = await api.uploadSample(taskId: created.taskId, sample: _sample('b'));
    expect(dup.sampleAccepted, isFalse);
    expect(dup.rejectionReason, 'duplicate_sampleId');

    final s3 = await api.uploadSample(taskId: created.taskId, sample: _sample('c'));
    expect(s3.status, 'TRIGGERED');
    expect(s3.spawnId, isNotNull);

    final ended = await api.endTask(taskId: created.taskId, requestId: 'r-end');
    expect(ended.status, 'ENDED');
  });

  test('非 GCJ02 不改标签路径：拒收', () async {
    final api = FakeStudyApi();
    final created = await api.createTask(
      regionId: 'library_entrance',
      requestId: 'r2',
      locationSource: 'SIMULATED',
    );
    final bad = await api.uploadSample(
      taskId: created.taskId,
      sample: LocationSample(
        sampleId: 'wgs',
        latitude: 1,
        longitude: 2,
        accuracyMeters: 5,
        sampledAt: DateTime.now().toUtc(),
        coordinateSystem: 'WGS84',
        source: 'SIMULATED',
      ),
    );
    expect(bad.sampleAccepted, isFalse);
    expect(bad.rejectionReason, 'coordinate_system');
    expect(bad.status, 'WAITING');
  });

  test('debugForceStatus PAUSED 保留累计演示', () async {
    final api = FakeStudyApi(dwellSamplesToTrigger: 10);
    final created = await api.createTask(
      regionId: 'library_entrance',
      requestId: 'r3',
      locationSource: 'SIMULATED',
    );
    await api.uploadSample(taskId: created.taskId, sample: _sample('1'));
    await api.uploadSample(taskId: created.taskId, sample: _sample('2'));
    api.debugForceStatus('PAUSED');
    final paused = await api.uploadSample(
      taskId: created.taskId,
      sample: _sample('3'),
    );
    expect(paused.status, 'PAUSED');
    expect(paused.pauseReason, 'NO_SIGNAL');
    expect(paused.effectiveSeconds, greaterThanOrEqualTo(0));
  });
}
