import '../model/study_models.dart';
import 'api_client.dart';

/// 自习任务端口。服务端四条路由为设计态，当前以 Fake 推进。
abstract interface class StudyApi {
  Future<TaskSnapshot> createTask({
    required String regionId,
    required String requestId,
    required String locationSource,
  });

  Future<TaskSnapshot> uploadSample({
    required String taskId,
    required LocationSampleDto sample,
  });

  Future<TaskSnapshot?> getCurrent();

  Future<TaskSnapshot> endTask({
    required String taskId,
    required String requestId,
  });
}

class HttpStudyApi implements StudyApi {
  const HttpStudyApi(this._client);

  final ApiClient _client;

  @override
  Future<TaskSnapshot> createTask({
    required String regionId,
    required String requestId,
    required String locationSource,
  }) async {
    final data = await _client.post(
      '/study/tasks',
      body: <String, dynamic>{
        'regionId': regionId,
        'requestId': requestId,
        'locationSource': locationSource,
      },
    );
    return TaskSnapshot.fromJson(data);
  }

  @override
  Future<TaskSnapshot> uploadSample({
    required String taskId,
    required LocationSampleDto sample,
  }) async {
    final data = await _client.post(
      '/study/tasks/${Uri.encodeComponent(taskId)}/samples',
      body: sample.toJson(),
    );
    return TaskSnapshot.fromJson(data);
  }

  @override
  Future<TaskSnapshot?> getCurrent() async {
    final data = await _client.get('/study/tasks/current');
    return TaskSnapshot.fromCurrentEnvelope(data);
  }

  @override
  Future<TaskSnapshot> endTask({
    required String taskId,
    required String requestId,
  }) async {
    final data = await _client.post(
      '/study/tasks/${Uri.encodeComponent(taskId)}/end',
      body: <String, dynamic>{'requestId': requestId},
    );
    return TaskSnapshot.fromJson(data);
  }
}
