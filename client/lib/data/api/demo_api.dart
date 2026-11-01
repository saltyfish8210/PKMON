import 'package:http/http.dart' as http;

import '../model/demo_models.dart';
import '../model/parsing.dart';
import 'api_client.dart';
import 'token_provider.dart';

/// 旧演示接口适配（独立 X-Demo-Session，与正式 Bearer 完全隔离）。
///
/// 仅用于旧页面与课堂演示；旧接口没有 captureRecordId，
/// 因此其成功结果不得作为正式捕获证据。
class DemoApi {
  DemoApi._(this._client, this._session);

  factory DemoApi({required Uri baseUrl, http.Client? httpClient}) {
    final session = _DemoSession();
    final client = ApiClient(
      baseUrl: baseUrl,
      tokens: const _EmptyTokens(),
      httpClient: httpClient,
      extraHeaders: session.headers,
    );
    return DemoApi._(client, session);
  }

  final ApiClient _client;
  final _DemoSession _session;

  String? get sessionId => _session.id;

  Future<void> connect() async {
    final data = await _client.post('/demo/sessions', authenticated: false);
    _session.id = requireString(data, 'sessionId');
  }

  Future<DemoState> state() async {
    final data = await _client.get('/demo/state', authenticated: false);
    return DemoState.fromJson(data);
  }

  Future<DemoState> explore() async {
    final data = await _client.post('/demo/explore', authenticated: false);
    return DemoState.fromJson(data);
  }

  Future<DemoState> reset() async {
    final data = await _client.post('/demo/reset', authenticated: false);
    return DemoState.fromJson(data);
  }

  Future<LegacyChallenge> challenge(String spawnId) async {
    final data = await _client.post(
      '/demo/capture/challenge',
      authenticated: false,
      body: <String, dynamic>{'spawnId': spawnId},
    );
    return LegacyChallenge.fromJson(data);
  }

  Future<LegacyAnswer> answer(String challengeId, String optionId) async {
    final data = await _client.post(
      '/demo/capture/answer',
      authenticated: false,
      body: <String, dynamic>{
        'challengeId': challengeId,
        'optionId': optionId,
      },
    );
    return LegacyAnswer.fromJson(data);
  }

  void close() => _client.close();
}

class _DemoSession {
  String? id;

  Map<String, String> headers() {
    final sessionId = id;
    if (sessionId == null || sessionId.isEmpty) return const {};
    return <String, String>{'X-Demo-Session': sessionId};
  }
}

class _EmptyTokens implements TokenProvider {
  const _EmptyTokens();

  @override
  Future<SessionToken?> current() async => null;
}
