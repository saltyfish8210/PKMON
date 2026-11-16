import '../model/collection_models.dart';
import 'api_client.dart';
import 'collection_api.dart';

/// 图鉴与背包端口（只读）。
///
/// 与 [CollectionApi] 分开，是为了让只依赖概览的页面与测试不被新接口影响；
/// 三个视图（概览／图鉴／背包）在服务端共用同一份收录事实。
abstract interface class CollectionDetailApi {
  Future<DexView> dex();

  Future<BagView> bag();
}

class HttpCollectionDetailApi implements CollectionDetailApi {
  const HttpCollectionDetailApi(this._client);

  final ApiClient _client;

  @override
  Future<DexView> dex() async {
    final data = await _client.get('/collection/dex');
    return DexView.fromJson(data);
  }

  @override
  Future<BagView> bag() async {
    final data = await _client.get('/collection/bag');
    return BagView.fromJson(data);
  }
}
