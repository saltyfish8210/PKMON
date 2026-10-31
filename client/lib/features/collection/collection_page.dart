import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/api/api_failure.dart';
import '../../data/api/collection_api.dart';
import '../../data/model/collection_models.dart';

/// 收藏概览页（骨架）：数量只来自服务端，不做本地累加。
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, required this.api});

  final CollectionApi api;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  late Future<CollectionSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.summary();
  }

  void _reload() {
    setState(() {
      _future = widget.api.summary();
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
        title: const Text('收藏概览'),
      ),
      body: SafeArea(
        child: FutureBuilder<CollectionSummary>(
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
            final summary = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.captureSide),
              children: [
                Text(
                  '已收集 ${summary.collectedSpeciesCount} / ${summary.totalSpeciesCount} 种',
                  style: const TextStyle(
                    fontSize: AppFontSizes.pageTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.base * 3),
                Text(
                  '累计捕获 ${summary.captureCount} 次',
                  style: const TextStyle(
                    fontSize: AppFontSizes.body,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.base * 6),
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
}
