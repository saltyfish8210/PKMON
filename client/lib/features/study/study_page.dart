import 'package:flutter/material.dart';

import '../../core/location/simulated_location_provider.dart';
import '../../core/tokens.dart';
import '../../widgets/app_buttons.dart';
import 'fake_study_api.dart';
import 'study_controller.dart';

/// 自习任务骨架页：Fake + 合成定位。标注模拟，不计真实奖励。
class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  late final StudyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StudyController(
      api: FakeStudyApi(dwellSamplesToTrigger: 3),
      location: SimulatedLocationProvider(
        interval: const Duration(seconds: 2),
      ),
    )..addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _controller.view;
    final task = v.task;

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('自习任务骨架'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base * 4),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base * 3),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.listCard),
            ),
            child: const Text(
              '模拟模式：FakeStudyApi + SimulatedLocationProvider。\n'
              '页面只展示返回状态，本地计时不能决定奖励。',
              style: TextStyle(
                color: AppColors.text,
                height: 1.5,
                fontSize: AppFontSizes.body,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base * 4),
          _row('状态', task?.status ?? 'IDLE'),
          _row('暂停原因', task?.pauseReason ?? '—'),
          _row(
            '有效时长',
            '${v.effectiveSeconds} / ${task?.requiredSeconds ?? 60} 秒',
          ),
          _row('spawnId', task?.spawnId ?? '—'),
          _row('采样中', v.listening ? '是' : '否'),
          if (v.lastError != null) ...[
            const SizedBox(height: AppSpacing.base * 3),
            Text(
              v.lastError!,
              style: const TextStyle(color: Colors.redAccent, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.base * 6),
          PrimaryButton(
            label: '开始模拟自习',
            onPressed: () => _controller.startStudy(),
          ),
          const SizedBox(height: AppSpacing.base * 2),
          SecondaryButton(
            label: '结束任务',
            onPressed: () => _controller.endStudy(),
          ),
          const SizedBox(height: AppSpacing.base * 2),
          TextButton(
            onPressed: () => _controller.retryPermission(),
            child: const Text('重试定位订阅'),
          ),
          if (task?.status == 'TRIGGERED' && task?.spawnId != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.base * 4),
              child: PrimaryButton(
                label: '前往答题（占位）',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '捕获模块接入点：spawnId=${task!.spawnId}（本页不发奖）',
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base * 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
