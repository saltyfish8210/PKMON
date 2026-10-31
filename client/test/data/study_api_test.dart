import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/study_api.dart';
import 'package:pkmon_app/data/model/study_models.dart';

import 'test_support.dart';

Map<String, dynamic> taskJson({
  String status = 'WAITING',
  int effectiveSeconds = 0,
  bool? sampleAccepted,
  String? rejectionReason,
}) {
  final json = <String, dynamic>{
    'taskId': 't1',
    'regionId': 'library_entrance',
    'status': status,
    'pauseReason': null,
    'effectiveSeconds': effectiveSeconds,
    'requiredSeconds': 600,
    'spawnId': null,
    'serverTime': '2026-10-19T02:00:00Z',
  };
  if (sampleAccepted != null) json['sampleAccepted'] = sampleAccepted;
  if (rejectionReason != null) json['rejectionReason'] = rejectionReason;
  return json;
}

void main() {
  group('HttpStudyApi', () {
    test('创建任务：路径与请求体', () async {
      late http.Request captured;
      final api = HttpStudyApi(clientWith(MockClient((request) async {
        captured = request;
        return envelope(taskJson());
      })));

      final task = await api.createTask(
        regionId: 'library_entrance',
        requestId: 'req-1',
        locationSource: 'SIMULATED',
      );

      expect(captured.url.path, '/api/v1/study/tasks');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['requestId'], 'req-1');
      expect(body['locationSource'], 'SIMULATED');
      expect(task.status, 'WAITING');
    });

    test('上传样本：字段齐全并解析 sampleAccepted', () async {
      late http.Request captured;
      final api = HttpStudyApi(clientWith(MockClient((request) async {
        captured = request;
        return envelope(taskJson(
          status: 'DWELLING',
          effectiveSeconds: 20,
          sampleAccepted: true,
        ));
      })));

      final task = await api.uploadSample(
        taskId: 't1',
        sample: LocationSampleDto(
          sampleId: 's1',
          latitude: 39.9925,
          longitude: 116.326,
          accuracyMeters: 12,
          sampledAt: DateTime.utc(2026, 10, 19, 2),
          coordinateSystem: 'GCJ02',
          source: 'SIMULATED',
        ),
      );

      expect(captured.url.path, '/api/v1/study/tasks/t1/samples');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['coordinateSystem'], 'GCJ02');
      expect(body['sampledAt'], '2026-10-19T02:00:00.000Z');
      expect(task.sampleAccepted, isTrue);
      expect(task.effectiveSeconds, 20);
    });

    test('current 无任务时返回 null', () async {
      final api = HttpStudyApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{'task': null}),
      )));
      expect(await api.getCurrent(), isNull);
    });

    test('current 有任务时解析快照', () async {
      final api = HttpStudyApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{'task': taskJson(status: 'PAUSED')}),
      )));
      final task = await api.getCurrent();
      expect(task?.status, 'PAUSED');
    });

    test('结束任务：路径与 requestId', () async {
      late http.Request captured;
      final api = HttpStudyApi(clientWith(MockClient((request) async {
        captured = request;
        return envelope(taskJson(status: 'ENDED'));
      })));

      final task = await api.endTask(taskId: 't1', requestId: 'req-end');
      expect(captured.url.path, '/api/v1/study/tasks/t1/end');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['requestId'], 'req-end');
      expect(task.status, 'ENDED');
    });
  });
}
