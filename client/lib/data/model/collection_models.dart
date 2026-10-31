import '../api/api_failure.dart';
import 'parsing.dart';

/// 收藏概览：数量只认服务端，客户端不做本地 +1。
class CollectionSummary {
  const CollectionSummary({
    required this.collectedSpeciesCount,
    required this.totalSpeciesCount,
    required this.captureCount,
  });

  factory CollectionSummary.fromJson(Map<String, dynamic> json) {
    final collected = requireInt(json, 'collectedSpeciesCount');
    final total = requireInt(json, 'totalSpeciesCount');
    final capture = requireInt(json, 'captureCount');
    if (collected < 0 || total < 0 || capture < 0) {
      throw ApiFailure.protocol('收藏概览数量为负');
    }
    return CollectionSummary(
      collectedSpeciesCount: collected,
      totalSpeciesCount: total,
      captureCount: capture,
    );
  }

  final int collectedSpeciesCount;
  final int totalSpeciesCount;
  final int captureCount;
}
