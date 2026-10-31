import '../model/collection_models.dart';
import 'api_client.dart';

/// 收藏概览端口（只读）。
abstract interface class CollectionApi {
  Future<CollectionSummary> summary();
}

class HttpCollectionApi implements CollectionApi {
  const HttpCollectionApi(this._client);

  final ApiClient _client;

  @override
  Future<CollectionSummary> summary() async {
    final data = await _client.get('/collection/summary');
    return CollectionSummary.fromJson(data);
  }
}
