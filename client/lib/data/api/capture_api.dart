import '../model/capture_models.dart';
import 'api_client.dart';

/// 捕获端口：开发遭遇、取题、作答、状态查询。
abstract interface class CaptureApi {
  Future<SpawnView> createDevSpawn({
    required String regionId,
    required String speciesId,
  });

  Future<ChallengeView> challenge({required String spawnId});

  Future<CaptureResult> answer({
    required String challengeId,
    required String requestId,
    required String optionId,
  });

  Future<ChallengeStatus> status({required String challengeId});
}

class HttpCaptureApi implements CaptureApi {
  const HttpCaptureApi(this._client);

  final ApiClient _client;

  @override
  Future<SpawnView> createDevSpawn({
    required String regionId,
    required String speciesId,
  }) async {
    final data = await _client.post(
      '/dev/spawns',
      body: <String, dynamic>{'regionId': regionId, 'speciesId': speciesId},
    );
    return SpawnView.fromJson(data);
  }

  @override
  Future<ChallengeView> challenge({required String spawnId}) async {
    final data = await _client.post(
      '/capture/challenge',
      body: <String, dynamic>{'spawnId': spawnId},
    );
    return ChallengeView.fromJson(data);
  }

  @override
  Future<CaptureResult> answer({
    required String challengeId,
    required String requestId,
    required String optionId,
  }) async {
    final data = await _client.post(
      '/capture/answer',
      body: <String, dynamic>{
        'challengeId': challengeId,
        'requestId': requestId,
        'optionId': optionId,
      },
    );
    return CaptureResult.fromJson(data);
  }

  @override
  Future<ChallengeStatus> status({required String challengeId}) async {
    final data = await _client.get(
      '/capture/challenges/${Uri.encodeComponent(challengeId)}',
    );
    return ChallengeStatus.fromJson(data);
  }
}
