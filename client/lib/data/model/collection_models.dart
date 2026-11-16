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

/// 图鉴条目：目录中的一种精灵 + 本人收录情况；未收录时 [count] 为 0、[firstCapturedAt] 为空。
class DexEntry {
  const DexEntry({
    required this.speciesId,
    required this.name,
    required this.count,
    this.firstCapturedAt,
  });

  factory DexEntry.fromJson(Map<String, dynamic> json) {
    final count = requireInt(json, 'count');
    if (count < 0) throw ApiFailure.protocol('图鉴条目数量为负');
    return DexEntry(
      speciesId: requireString(json, 'speciesId'),
      name: requireString(json, 'name'),
      count: count,
      firstCapturedAt: optionalUtcTime(json, 'firstCapturedAt'),
    );
  }

  final String speciesId;
  final String name;
  final int count;
  final DateTime? firstCapturedAt;

  bool get captured => count > 0;
}

/// 图鉴整体：目录全部种类 + 已收种类数。
class DexView {
  const DexView({
    required this.collectedSpeciesCount,
    required this.totalSpeciesCount,
    required this.entries,
  });

  factory DexView.fromJson(Map<String, dynamic> json) {
    final entries = asJsonList(json['entries'], 'entries')
        .map((item) => DexEntry.fromJson(asJsonMap(item, 'entries[]')))
        .toList(growable: false);
    final collected = requireInt(json, 'collectedSpeciesCount');
    final total = requireInt(json, 'totalSpeciesCount');
    if (collected < 0 || total < 0) throw ApiFailure.protocol('图鉴数量为负');
    return DexView(
      collectedSpeciesCount: collected,
      totalSpeciesCount: total,
      entries: entries,
    );
  }

  final int collectedSpeciesCount;
  final int totalSpeciesCount;
  final List<DexEntry> entries;
}

/// 背包条目：本人实际持有的一种精灵。
class BagEntry {
  const BagEntry({
    required this.speciesId,
    required this.name,
    required this.count,
    this.latestCapturedAt,
  });

  factory BagEntry.fromJson(Map<String, dynamic> json) {
    final count = requireInt(json, 'count');
    if (count <= 0) throw ApiFailure.protocol('背包条目数量非法');
    return BagEntry(
      speciesId: requireString(json, 'speciesId'),
      name: requireString(json, 'name'),
      count: count,
      latestCapturedAt: optionalUtcTime(json, 'latestCapturedAt'),
    );
  }

  final String speciesId;
  final String name;
  final int count;
  final DateTime? latestCapturedAt;
}

/// 背包整体：总数量与按最近收录时间倒序的条目。
class BagView {
  const BagView({
    required this.totalCount,
    required this.speciesCount,
    required this.entries,
  });

  factory BagView.fromJson(Map<String, dynamic> json) {
    final entries = asJsonList(json['entries'], 'entries')
        .map((item) => BagEntry.fromJson(asJsonMap(item, 'entries[]')))
        .toList(growable: false);
    final total = requireInt(json, 'totalCount');
    final species = requireInt(json, 'speciesCount');
    if (total < 0 || species < 0) throw ApiFailure.protocol('背包数量为负');
    return BagView(
      totalCount: total,
      speciesCount: species,
      entries: entries,
    );
  }

  final int totalCount;
  final int speciesCount;
  final List<BagEntry> entries;
}
