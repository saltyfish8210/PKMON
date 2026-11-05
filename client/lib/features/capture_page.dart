import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/tokens.dart';
import '../models/sprite.dart';
import '../widgets/app_buttons.dart';

/// 答题抓捕页。全屏覆盖，进去之后不与地图交互（设计规范里的「单屏单任务」）。
///
/// **取题不在这里做**：题目由地图页先调 `capture/challenge` 拿到，再作为参数传进来。
/// 这样加载态统一显示在主页的顶部进度条上，不用两处各写一套。
///
/// **判题也不在这里**：客户端只上报「选了哪个选项」，对错由服务端定。
/// 这是刻意的——客户端自己判题的话，改个内存变量就能白拿精灵。
class CapturePage extends StatefulWidget {
  const CapturePage({super.key, required this.api, required this.challenge});

  final Api api;

  /// `capture/challenge` 返回的题目对象：
  /// `{challengeId, spawnId, name, question, options:[{id,text}], source}`
  final Map<String, dynamic> challenge;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  /// 提交中：按钮变灰、禁返回，防止重复提交
  bool _submitting = false;

  /// 服务端结算结果。非空即表示已出结果，界面切成结果态
  Map<String, dynamic>? _result;

  /// 网络异常提示。**不会在本地发奖**，只是提示重试
  String? _error;

  Future<void> _submit(String optionId) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final data = await widget.api.request(
        'demo/capture/answer',
        body: {
          'challengeId': widget.challenge['challengeId'],
          'optionId': optionId,
        },
      );
      if (!mounted) return;
      setState(() => _result = data);
    } catch (e) {
      if (!mounted) return;
      // 请求没成功时题目仍然有效，可以直接再点一次
      setState(() => _error = '网络未完成结算，请重试。不会在客户端自行发放精灵。');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 提交期间拦住系统返回手势，避免带着半个请求退出
      canPop: !_submitting,
      child: Scaffold(
        backgroundColor: AppColors.primarySoft,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.captureSide,
              AppSpacing.base * 2,
              AppSpacing.captureSide,
              AppSpacing.base * 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: AppSpacing.base * 2),
                _buildSpriteHeader(),
                const SizedBox(height: AppSpacing.base * 6),
                _result == null ? _buildQuestionCard() : _buildResultCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 顶栏

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          color: AppColors.primary,
          tooltip: '返回地图',
          constraints: const BoxConstraints(
            minWidth: AppSpacing.iconHitTarget,
            minHeight: AppSpacing.iconHitTarget,
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '一次新的相遇',
              style: TextStyle(
                fontSize: AppFontSizes.body,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // 占位，让中间标题真正居中
        const SizedBox(width: AppSpacing.iconHitTarget),
      ],
    );
  }

  // ------------------------------------------------------------ 精灵头部区

  Widget _buildSpriteHeader() {
    return Column(
      children: [
        Text(
          '${dexSlots[siegeLionSlotIndex].displayId}  /  ${dexSlots[siegeLionSlotIndex].location}',
          style: const TextStyle(
            fontSize: AppFontSizes.secondary,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 2),
        const Text(
          '攻城狮',
          style: TextStyle(
            fontSize: AppFontSizes.captureTitle,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.base * 3),
        Image.asset(
          AppAssets.siegeLion,
          height: 195,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox(height: 195),
        ),
        const SizedBox(height: AppSpacing.base * 3),
        const Text(
          '它正在寻找一位并肩改 bug 的伙伴。',
          style: TextStyle(
            fontSize: AppFontSizes.body,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 答题卡

  Widget _buildQuestionCard() {
    final options = (widget.challenge['options'] as List).cast<Map>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.captureCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '校园小问答',
            style: TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 3),

          Text(
            widget.challenge['question'] as String,
            style: const TextStyle(
              fontSize: AppFontSizes.question,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 4),

          for (final option in options) _buildOption(option),

          if (_submitting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.base * 2),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.divider,
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.base * 2),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: AppFontSizes.secondary,
                  color: AppColors.errorText,
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.base * 3),
          Text(
            widget.challenge['source'] as String,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(Map option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base * 2.5),
      child: SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonMinHeight,
        child: OutlinedButton(
          onPressed: _submitting ? null : () => _submit(option['id'] as String),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(
            '${option['id']}  ${option['text']}',
            style: const TextStyle(fontSize: AppFontSizes.body),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 结果卡

  Widget _buildResultCard() {
    final success = _result!['success'] == true;
    final message = _result!['message'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.captureCard),
      ),
      child: Column(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.refresh_rounded,
            size: 48,
            color: success ? AppColors.primary : AppColors.errorText,
          ),
          const SizedBox(height: AppSpacing.base * 4),

          Text(
            success ? '成为伙伴了！' : '下次一定会更熟悉',
            style: const TextStyle(
              fontSize: AppFontSizes.question,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 3),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 6),

          PrimaryButton(
            label: '返回地图',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.base * 4),

          const Text(
            '后端完成答案校验与捕获结算',
            style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}
