import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/section_header.dart';

/// 个人中心页。对应设计稿 `07-个人页.png`。
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.collected,
    required this.totalSpecies,
    required this.taskRunning,
    required this.helloText,
    required this.busy,
    required this.onReset,
    required this.onTasks,
  });

  /// 已捕获种类数（来自后端）
  final int collected;

  final int totalSpecies;

  /// 任务模式是否进行中（纯客户端状态）
  final bool taskRunning;

  /// 后端健康检查返回的文本
  final String helloText;

  final bool busy;
  final VoidCallback onReset;
  final VoidCallback onTasks;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mapContentSide,
        AppSpacing.base * 5,
        AppSpacing.mapContentSide,
        AppSpacing.base * 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            eyebrow: 'EXPLORER PROFILE',
            title: '你好，校园探索者',
            subtitle: '课堂演示模式：数据来自本机服务端的演示接口。',
          ),

          const SizedBox(height: AppSpacing.base * 8),
          _buildAvatar(),
          const SizedBox(height: AppSpacing.base * 6),

          // 统计与设置。后三项的说明文字都反映当前真实状态，不是写死的。
          _InfoRow(
            icon: Icons.menu_book_outlined,
            title: '已收集种类',
            value: '$collected / $totalSpecies',
            highlighted: true,
          ),
          const _RowDivider(),
          const _InfoRow(
            icon: Icons.compass_calibration_outlined,
            title: '位置来源',
            value: '课堂模拟，不请求真实定位权限',
          ),
          const _RowDivider(),
          _InfoRow(
            icon: Icons.cloud_outlined,
            title: '后端连接',
            value: helloText,
          ),
          const _RowDivider(),
          _InfoRow(
            icon: Icons.timer_outlined,
            title: '任务模式',
            value: taskRunning ? '模拟自习进行中' : '仅由用户主动开启',
            onTap: onTasks,
          ),

          const SizedBox(height: AppSpacing.base * 8),

          SecondaryButton(
            label: '重新开始演示',
            icon: Icons.restart_alt,
            // 加载中禁用，避免重复请求
            onPressed: busy ? null : onReset,
          ),

          const SizedBox(height: AppSpacing.base * 6),

          const Text(
            '本页是「进入演示（不登录）」的体验模式：位置由课堂模拟样本提供，数据来自服务端演示接口，'
            '刷新页面会新建会话。账号注册/登录、自习任务、收录与图鉴/背包在登录后使用真实接口与文件数据库。',
            style: TextStyle(
              fontSize: AppFontSizes.secondary,
              color: AppColors.secondaryText,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  /// 头像：浅主色圆底 + 主色人形图标
  Widget _buildAvatar() {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person_outline, size: 46, color: AppColors.primary),
      ),
    );
  }
}

/// 一行「图标 + 标题 + 右侧值」。[onTap] 非空时整行可点。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.highlighted = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;

  /// 数值用主色加粗（「已收集种类」用）
  final bool highlighted;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base * 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.base * 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppFontSizes.body,
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.base * 4),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppFontSizes.body,
                color: highlighted ? AppColors.primary : AppColors.secondaryText,
                fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.divider);
  }
}
