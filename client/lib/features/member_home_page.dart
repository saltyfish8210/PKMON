import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../data/api/api_client.dart';
import '../data/api/api_failure.dart';
import '../data/api/collection_api.dart';
import '../data/model/collection_models.dart';
import '../models/sprite.dart';
import 'collection/collection_page.dart';
import 'study/study_page.dart';

/// 登录后的入口只使用账号接口，不读取游客演示会话的收藏状态。
class MemberHomePage extends StatefulWidget {
  const MemberHomePage({
    super.key,
    required this.client,
    required this.nickname,
    required this.onLogout,
  });

  final ApiClient client;
  final String nickname;
  final Future<void> Function() onLogout;

  @override
  State<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends State<MemberHomePage> {
  late Future<CollectionSummary> _summary;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _summary = HttpCollectionApi(widget.client).summary();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _summary = HttpCollectionApi(widget.client).summary();
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    _refresh();
  }

  Future<void> _logout() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    appBar: AppBar(
      title: const Text('PKMon 校园探索'),
      actions: [
        TextButton(
          onPressed: _leaving ? null : _logout,
          child: const Text('退出登录'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      children: [
        Text(
          '${widget.nickname}，开始今天的自习吧',
          style: const TextStyle(
            fontSize: AppFontSizes.question,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 5),
        Card(
          color: AppColors.primarySoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Image.asset(AppAssets.siegeLion, height: 150)),
                const Text(
                  '自习，遇见新的伙伴',
                  style: TextStyle(
                    fontSize: AppFontSizes.pageTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.base * 3),
                const Text(
                  '在区域内完成驻留，遇见攻城狮；答对问题，将它收入收藏。',
                  style: TextStyle(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.base * 4),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonMinHeight,
                  child: FilledButton.icon(
                    onPressed: () => _open(StudyPage(client: widget.client)),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('进入自习任务'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base * 5),
        Row(
          children: [
            const Expanded(
              child: Text(
                '我的收藏',
                style: TextStyle(
                  fontSize: AppFontSizes.question,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: '刷新收藏',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        FutureBuilder<CollectionSummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error is ApiFailure ? error.message : '收藏加载失败，请重试'),
                  TextButton(onPressed: _refresh, child: const Text('重试')),
                ],
              );
            }
            final summary = snapshot.data!;
            return Text(
              '已收集 ${summary.collectedSpeciesCount} / '
              '${summary.totalSpeciesCount} 种 · 累计捕获 ${summary.captureCount} 次',
            );
          },
        ),
        const SizedBox(height: AppSpacing.base * 4),
        OutlinedButton.icon(
          onPressed: () =>
              _open(CollectionPage(api: HttpCollectionApi(widget.client))),
          icon: const Icon(Icons.collections_bookmark_outlined),
          label: const Text('查看收藏'),
        ),
        const SizedBox(height: AppSpacing.base * 5),
        const Text(
          '课堂演示可使用模拟位置；真实到场定位另行验证。',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: AppFontSizes.secondary,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}
