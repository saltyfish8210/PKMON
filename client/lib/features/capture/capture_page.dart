import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/model/capture_models.dart';
import '../../data/model/collection_models.dart';
import 'capture_controller.dart';

/// 答题捕获页（骨架）。
///
/// 页面只消费 [CaptureController.state] 并转发用户操作，不直接发请求、不判定结果。
/// 控制器由调用方创建与释放（入口接线由余星晨完成）。
class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.spawnId,
    required this.controller,
  });

  final String spawnId;
  final CaptureController controller;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.spawnId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      appBar: AppBar(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('一次新的相遇'),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<CaptureUiState>(
          valueListenable: widget.controller.state,
          builder: (context, state, _) => _buildBody(state),
        ),
      ),
    );
  }

  Widget _buildBody(CaptureUiState state) {
    return switch (state) {
      CaptureIdle() => const SizedBox.shrink(),
      CaptureLoading() => _status(const CircularProgressIndicator(), '正在取题…'),
      CaptureFailed(:final message, :final retryable) => _failed(message, retryable),
      CaptureExpired(:final message) => _expired(message),
      CaptureUnknown(:final message) => _unknown(message),
      CaptureCaptured(:final summary) => _captured(summary),
      CaptureReady(
        :final challenge,
        :final lastError,
        :final lastResultWasWrong
      ) =>
        _question(challenge, lastError, lastResultWasWrong, submitting: false),
      CaptureSubmitting(:final challenge) =>
        _question(challenge, null, false, submitting: true),
    };
  }

  Widget _status(Widget indicator, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: AppSpacing.base * 4),
          Text(text, style: const TextStyle(color: AppColors.secondaryText)),
        ],
      ),
    );
  }

  Widget _question(
    ChallengeView challenge,
    String? lastError,
    bool wrong, {
    required bool submitting,
  }) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.captureSide),
      children: [
        Text(
          '${challenge.speciesName} · ${challenge.questionId}',
          style: const TextStyle(
            fontSize: AppFontSizes.secondary,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 3),
        Text(
          challenge.questionText,
          style: const TextStyle(
            fontSize: AppFontSizes.question,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 4),
        for (final option in challenge.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.base * 2),
            child: SizedBox(
              height: AppSpacing.buttonMinHeight,
              child: OutlinedButton(
                onPressed: submitting
                    ? null
                    : () => widget.controller.submit(option.optionId),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${option.optionId}  ${option.text}'),
                ),
              ),
            ),
          ),
        if (submitting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.base * 3),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (wrong)
          _hint('这次没有答对，可以再试一次。', AppColors.errorText),
        if (lastError != null) _hint(lastError, AppColors.errorText),
        if (challenge.isSimulated)
          _hint('模拟遇见攻城狮：本次遭遇来自开发入口，不是真实到场。',
              AppColors.secondaryText),
      ],
    );
  }

  Widget _hint(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.base * 2),
        child: Text(
          text,
          style: TextStyle(fontSize: AppFontSizes.secondary, color: color),
        ),
      );

  Widget _captured(CollectionSummary? summary) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.captureSide),
      children: [
        const SizedBox(height: AppSpacing.base * 8),
        const Icon(Icons.check_circle_outline,
            size: 72, color: AppColors.primary),
        const SizedBox(height: AppSpacing.base * 4),
        const Text(
          '成为伙伴了！',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppFontSizes.captureTitle,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 3),
        Text(
          summary == null
              ? '已收入图鉴（收藏数量暂未更新）'
              : '已收集 ${summary.collectedSpeciesCount} / ${summary.totalSpeciesCount} 种，'
                  '累计捕获 ${summary.captureCount} 次',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppFontSizes.body,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 8),
        SizedBox(
          height: AppSpacing.buttonMinHeight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('返回地图'),
          ),
        ),
      ],
    );
  }

  Widget _unknown(String message) {
    return _message(
      title: '结果待确认',
      body: message,
      actionLabel: '重新确认',
      onAction: widget.controller.retry,
    );
  }

  Widget _expired(String message) {
    return _message(
      title: '挑战已过期',
      body: message,
      actionLabel: '返回地图',
      onAction: () => Navigator.of(context).pop(),
    );
  }

  Widget _failed(String message, bool retryable) {
    return _message(
      title: '没能完成这次相遇',
      body: message,
      actionLabel: retryable ? '重试' : '返回地图',
      onAction: retryable
          ? widget.controller.retry
          : () => Navigator.of(context).pop(),
    );
  }

  Widget _message({
    required String title,
    required String body,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.captureSide),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: AppFontSizes.question,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.base * 3),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppFontSizes.body,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.base * 6),
            SizedBox(
              height: AppSpacing.buttonMinHeight,
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
