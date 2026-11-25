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
    this.nickname,
    this.onOpenCollection,
    this.onOpenStudy,
    this.onLogout,
  });

  /// 已登录用户的昵称；为 null 表示处于「进入演示（不登录）」模式。
  final String? nickname;

  /// 打开账号收藏页（概览/图鉴/背包）；演示模式下为 null。
  final VoidCallback? onOpenCollection;

  /// 打开自习任务页（真实接口）；演示模式下为 null。
  final VoidCallback? onOpenStudy;

  /// 退出登录；演示模式下为 null。
  final Future<void> Function()? onLogout;

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
          SectionHeader(
            eyebrow: 'EXPLORER PROFILE',
            title: nickname == null ? '你好，校园探索者' : '你好，$nickname',
            subtitle: nickname == null
                ? '课堂演示模式：数据来自本机服务端的演示接口。'
                : '已登录账号：地图、图鉴、收藏都读这个账号的数据。',
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

          if (onOpenStudy != null) ...[
            PrimaryButton(
              label: '开始自习任务（真实接口）',
              icon: Icons.directions_walk,
              onPressed: onOpenStudy,
            ),
            const SizedBox(height: AppSpacing.base * 3),
          ],

          if (onOpenCollection != null) ...[
            SecondaryButton(
              label: '我的收藏（概览 / 图鉴 / 背包）',
              icon: Icons.collections_bookmark_outlined,
              onPressed: onOpenCollection,
            ),
            const SizedBox(height: AppSpacing.base * 3),
          ],

          SecondaryButton(
            label: '刷新账号数据',
            icon: Icons.restart_alt,
            // 加载中禁用，避免重复请求
            onPressed: busy ? null : onReset,
          ),

          const SizedBox(height: AppSpacing.base * 6),

          if (onLogout != null) ...[
            _LogoutButton(onLogout: onLogout!),
            const SizedBox(height: AppSpacing.base * 5),
          ],

          Text(
            '地图、图鉴、背包与统计使用当前账号的收录记录。定位样本为模拟数据。',
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

/// 退出登录按钮：单独抽出来，避免把异步回调直接塞进 build。
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onLogout(),
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('退出登录'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.errorText,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
