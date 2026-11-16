import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/api/api_failure.dart';
import '../../data/api/collection_api.dart';
import '../../data/api/collection_detail_api.dart';
import '../../data/model/collection_models.dart';

/// 收藏页：概览 + 图鉴 + 背包。
///
/// 三块数字都来自服务端同一份收录事实，页面不做本地累加。
/// [detail] 为空时只显示概览，供不关心图鉴/背包的调用方继续使用。
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, required this.api, this.detail});

  final CollectionApi api;
  final CollectionDetailApi? detail;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionData {
  const _CollectionData({required this.summary, this.dex, this.bag});

  final CollectionSummary summary;
  final DexView? dex;
  final BagView? bag;
}

class _CollectionPageState extends State<CollectionPage> {
  late Future<_CollectionData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CollectionData> _load() async {
    final detail = widget.detail;
    if (detail == null) {
      return _CollectionData(summary: await widget.api.summary());
    }
    final results = await Future.wait<Object>([
      widget.api.summary(),
      detail.dex(),
      detail.bag(),
    ]);
    return _CollectionData(
      summary: results[0] as CollectionSummary,
      dex: results[1] as DexView,
      bag: results[2] as BagView,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: const Text('我的收藏'),
      ),
      body: SafeArea(
        child: FutureBuilder<_CollectionData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is ApiFailure ? error.message : '加载失败，请重试';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.captureSide),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                      const SizedBox(height: AppSpacing.base * 4),
                      FilledButton(onPressed: _reload, child: const Text('重试')),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.captureSide),
              children: [
                ..._summaryBlock(data.summary),
                if (data.dex != null) ..._dexBlock(data.dex!),
                if (data.bag != null) ..._bagBlock(data.bag!),
                const SizedBox(height: AppSpacing.base * 4),
                SizedBox(
                  height: AppSpacing.buttonMinHeight,
                  child: OutlinedButton(
                    onPressed: _reload,
                    child: const Text('刷新'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _summaryBlock(CollectionSummary summary) {
    return [
      Text(
        '已收集 ${summary.collectedSpeciesCount} / ${summary.totalSpeciesCount} 种',
        style: const TextStyle(
          fontSize: AppFontSizes.pageTitle,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: AppSpacing.base * 2),
      Text(
        '累计捕获 ${summary.captureCount} 次',
        style: const TextStyle(
          fontSize: AppFontSizes.body,
          color: AppColors.secondaryText,
        ),
      ),
      const SizedBox(height: AppSpacing.base * 6),
    ];
  }

  List<Widget> _dexBlock(DexView dex) {
    return [
      _sectionTitle('图鉴', '${dex.collectedSpeciesCount} / ${dex.totalSpeciesCount} 种已解锁'),
      const SizedBox(height: AppSpacing.base * 3),
      for (final entry in dex.entries) _dexRow(entry),
      const SizedBox(height: AppSpacing.base * 6),
    ];
  }

  Widget _dexRow(DexEntry entry) {
    final captured = entry.captured;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base * 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base * 4,
        vertical: AppSpacing.base * 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: captured ? AppColors.primarySoft : AppColors.page,
              shape: BoxShape.circle,
            ),
            child: Text(
              captured ? '★' : '?',
              style: TextStyle(
                fontSize: AppFontSizes.body,
                color: captured ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.base * 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  captured ? entry.name : '未解锁',
                  style: TextStyle(
                    fontSize: AppFontSizes.body,
                    fontWeight: FontWeight.w600,
                    color: captured ? AppColors.text : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  captured ? '已收录 ${entry.count} 次' : '驻留达标后答题即可解锁',
                  style: const TextStyle(
                    fontSize: AppFontSizes.secondary,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _bagBlock(BagView bag) {
    return [
      _sectionTitle('背包', '共 ${bag.totalCount} 只 · ${bag.speciesCount} 种'),
      const SizedBox(height: AppSpacing.base * 3),
      if (bag.entries.isEmpty)
        Container(
          padding: const EdgeInsets.all(AppSpacing.base * 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Text(
            '背包还是空的。去完成一次自习，在区域里驻留达标后答题，就能收到第一只精灵。',
            style: TextStyle(
              fontSize: AppFontSizes.secondary,
              color: AppColors.secondaryText,
              height: 1.6,
            ),
          ),
        )
      else
        for (final entry in bag.entries) _bagRow(entry),
    ];
  }

  Widget _bagRow(BagEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.base * 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base * 4,
        vertical: AppSpacing.base * 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Text(
            '★',
            style: TextStyle(fontSize: AppFontSizes.body, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.base * 3),
          Expanded(
            child: Text(
              entry.name,
              style: const TextStyle(
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          Text(
            '×${entry.count}',
            style: const TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String trailing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppFontSizes.body,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: AppSpacing.base * 2),
        Expanded(
          child: Text(
            trailing,
            style: const TextStyle(
              fontSize: AppFontSizes.secondary,
              color: AppColors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}
