import 'package:flutter/material.dart';

import '../core/tokens.dart';
import 'app_buttons.dart';

/// 任务模式弹窗。
///
/// 这一版是**纯界面原型**：任务的开始/结束只是本地一个布尔值，
/// 不采集真实位置、不计算驻留时长。真正的驻留判定要等接上定位之后。
///
/// [running] 表示当前是否已经在任务中（决定按钮显示"开始"还是"结束"）。
/// 弹窗会先关掉自己，再回调 [onToggle] / [onFastForward]，调用方只管改状态。
Future<void> showTaskSheet(
  BuildContext context, {
  required bool running,
  required VoidCallback onToggle,
  required VoidCallback onFastForward,
  VoidCallback? onOpenStudySkeleton,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '留一段时间，给校园',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 3),
          const Text(
            '图书馆自习 · 任务模式原型',
            style: TextStyle(fontSize: 16, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.base * 3),
          const Text(
            '正式版由你主动开启定位任务。当前仅演示开始、结束与奖励入口，'
            '不采集真实位置，也不计算驻留时长。',
            style: TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.secondaryText,
              height: 1.7,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 6),

          // 读的是打开弹窗时的状态：正在跑就显示"结束"，否则显示"开始"
          PrimaryButton(
            label: running ? '结束模拟任务' : '开始模拟自习',
            onPressed: () {
              Navigator.of(ctx).pop();
              onToggle();
            },
          ),

          // 只有任务进行中才有「快进」，否则没意义
          if (running)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.base),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onFastForward();
                  },
                  child: const Text('快进至完成（演示）'),
                ),
              ),
            ),

          if (onOpenStudySkeleton != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.base),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onOpenStudySkeleton();
                  },
                  child: const Text('打开自习骨架（模拟）'),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
