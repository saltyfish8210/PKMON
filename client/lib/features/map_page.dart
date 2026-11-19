import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../models/sprite.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_tag.dart';
import '../widgets/pill_chip.dart';

/// 地图主界面（App 默认首页）。
///
/// **地图是画出来的示意图，不是真实地图**——设计稿本身也是这么画的。
/// 接高德 SDK 之前，先把版式和交互定下来。
///
/// 底部面板有**三种形态**，由 `captured` / `nearby` 决定：
/// 没走到图书馆 → 「模拟走到图书馆」；精灵出现 → 「遇见」；已捕获 → 「查看我的图鉴」。
class MapPage extends StatelessWidget {
  const MapPage({
    super.key,
    required this.locationLabel,
    required this.nearby,
    required this.captured,
    required this.taskRunning,
    required this.actionEnabled,
    required this.collected,
    required this.totalSpecies,
    required this.helloText,
    required this.onExplore,
    required this.onCapture,
    required this.onGoToDex,
    required this.onTasks,
    this.spriteAsset = AppAssets.siegeLion,
    this.spriteLabel = '攻城狮',
  });

  /// 当前模拟位置，如「校园南门」
  final String locationLabel;

  /// 精灵是否已出现在地图上（后端驱动）
  final bool nearby;

  /// 是否已捕获（后端驱动）
  final bool captured;

  /// 任务模式是否进行中
  final bool taskRunning;

  /// 主按钮是否可点（未就绪 / 加载中时为 false）
  final bool actionEnabled;

  final int collected;
  final int totalSpecies;

  /// 后端健康检查返回的文本，显示在页脚
  final String helloText;

  final VoidCallback onExplore;
  final VoidCallback onCapture;
  final VoidCallback onGoToDex;
  final VoidCallback onTasks;

  /// 地图上出现的精灵图（自习任务演示时用占位精灵）。
  final String spriteAsset;

  /// 精灵名，用于气泡文字。
  final String spriteLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: _buildMapArea(context)),
        _buildBottomPanel(context),
      ],
    );
  }

  // ---------------------------------------------------------------- 顶部栏

  Widget _buildTopBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mapContentSide,
        AppSpacing.base * 3,
        AppSpacing.base * 2,
        AppSpacing.base * 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PKMon',
                  style: TextStyle(
                    fontSize: AppFontSizes.pageTitle,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: AppSpacing.base),
                Text(
                  '今天，遇见校园的另一面',
                  style: TextStyle(
                    fontSize: AppFontSizes.secondary,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTasks,
            icon: const Icon(Icons.timer_outlined),
            color: AppColors.primary,
            tooltip: '任务模式',
            constraints: const BoxConstraints(
              minWidth: AppSpacing.iconHitTarget,
              minHeight: AppSpacing.iconHitTarget,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 地图区

  Widget _buildMapArea(BuildContext context) {
    // 用 LayoutBuilder 拿到实际可用尺寸，再按比例摆元素。
    // 这样在 360×800 和 412×915 两种屏幕上都成比例，不会错位。
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        // 精灵出现后玩家标记会挪一下，避免挡住精灵
        final playerAt = (nearby || captured) ? 0.42 : 0.68;

        return Stack(
          children: [
            // 1. 地面底色
            Positioned.fill(child: Container(color: AppColors.mapGround)),

            // 2. 道路
            Positioned(
              left: -w * 0.1,
              right: -w * 0.1,
              top: h * 0.42,
              child: Container(height: 16, color: AppColors.mapRoad),
            ),
            Positioned(
              left: -w * 0.1,
              top: h * 0.58,
              child: Transform.rotate(
                angle: -0.12,
                child: Container(width: w * 1.3, height: 14, color: AppColors.mapRoad),
              ),
            ),

            // 3. 树
            ..._buildTrees(w, h),

            // 4. 地标
            _buildBuilding(
              left: w * 0.05,
              top: h * 0.10,
              width: w * 0.34,
              height: h * 0.20,
              label: '图书馆',
            ),
            _buildBuilding(
              left: w * 0.03,
              top: h * 0.64,
              width: w * 0.32,
              height: h * 0.18,
              label: '教学楼',
            ),

            // 5. 银杏湖
            Positioned(
              right: w * 0.06,
              top: h * 0.30,
              child: Container(
                width: w * 0.42,
                height: h * 0.26,
                decoration: BoxDecoration(
                  color: AppColors.mapWater,
                  borderRadius: BorderRadius.circular(48),
                ),
              ),
            ),
            Positioned(
              right: w * 0.12,
              top: h * 0.44,
              child: Text(
                '银杏湖',
                style: TextStyle(
                  fontSize: AppFontSizes.body,
                  color: AppColors.primary.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // 6. 校园南门
            Positioned(
              right: w * 0.10,
              top: h * 0.62,
              child: const _MapLabel(
                icon: Icons.door_front_door_outlined,
                text: '校园南门',
              ),
            ),

            // 7. 玩家标记
            Positioned(
              left: w * playerAt - 48,
              top: h * 0.52 - 48,
              child: _buildPlayerMarker(),
            ),

            // 8. 精灵（只在出现时渲染）
            if (nearby) _buildNearbySprite(w, h),

            // 9. 左上角位置标签
            const Positioned(
              left: AppSpacing.mapContentSide,
              top: AppSpacing.base * 3,
              child: PillChip(
                icon: Icons.science_outlined,
                label: '模拟位置 · 示意地图',
              ),
            ),

            // 10. 右下角：回到当前位置（只是弹个提示，地图不动）
            Positioned(
              right: AppSpacing.mapContentSide,
              bottom: AppSpacing.base * 5,
              child: _buildRoundButton(context),
            ),

            // 11. 任务进行中的左下角状态条
            if (taskRunning)
              Positioned(
                left: AppSpacing.mapContentSide,
                bottom: AppSpacing.base * 5,
                child: ActionChip(
                  avatar: const Icon(Icons.timer, size: 18, color: AppColors.primary),
                  label: const Text(
                    '模拟自习进行中',
                    style: TextStyle(fontSize: AppFontSizes.secondary),
                  ),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.divider),
                  onPressed: onTasks,
                ),
              ),
          ],
        );
      },
    );
  }

  /// 精灵本体。点它直接进答题页（和点底部按钮等价）。
  Widget _buildNearbySprite(double w, double h) {
    return Positioned(
      left: w * 0.43,
      top: h * 0.21,
      child: Semantics(
        label: '遇见',
        button: true,
        child: InkWell(
          onTap: actionEnabled ? onCapture : null,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Image.asset(
                spriteAsset,
                width: 90,
                height: 90,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 90,
                  height: 90,
                ),
              ),
              const AppTag(
                label: '点击遇见',
                icon: Icons.auto_awesome,
                gold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 散落的树。写死坐标是为了每次布局稳定，不用随机数。
  List<Widget> _buildTrees(double w, double h) {
    const positions = [
      [0.07, 0.04], [0.22, 0.06], [0.46, 0.05], [0.60, 0.12],
      [0.08, 0.36], [0.30, 0.30], [0.16, 0.50], [0.06, 0.86],
      [0.28, 0.90], [0.52, 0.88], [0.72, 0.82], [0.90, 0.72],
      [0.86, 0.14], [0.68, 0.24], [0.44, 0.72], [0.20, 0.74],
    ];
    return [
      for (final p in positions)
        Positioned(
          left: w * p[0],
          top: h * p[1],
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.mapTree,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ];
  }

  Widget _buildBuilding({
    required double left,
    required double top,
    required double width,
    required double height,
    required String label,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MapLabel(icon: Icons.local_library_outlined, text: label),
          const SizedBox(height: AppSpacing.base * 2),
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.mapBuilding,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  /// 玩家标记：半透明感知圈 + 主色实心圆 + 方向箭头
  Widget _buildPlayerMarker() {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('当前模拟位置：$locationLabel')),
          );
        },
        child: const SizedBox(
          width: AppSpacing.iconHitTarget,
          height: AppSpacing.iconHitTarget,
          child: Icon(Icons.my_location, size: 22, color: AppColors.primary),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 底部面板

  Widget _buildBottomPanel(BuildContext context) {
    // 三种形态。captured 优先于 nearby（后端保证二者互斥）
    final String name = spriteLabel.isEmpty ? '精灵' : spriteLabel;
    final String description;
    final IconData icon;
    final String label;
    final VoidCallback action;
    // 「查看我的图鉴」只是切 tab，不依赖后端，所以永远可点
    final bool enabled;

    if (captured) {
      description = '$name 已经收入图鉴，去收藏里看看。';
      icon = Icons.auto_stories_outlined;
      label = '查看收藏';
      action = onGoToDex;
      enabled = true;
    } else if (nearby) {
      description = ' 出现了，回答一个问题认识它。';
      icon = Icons.auto_awesome;
      label = '遇见$name';
      action = onCapture;
      enabled = actionEnabled;
    } else {
      description = '走近图书馆，发现一台还在改 bug 的攻城狮。';
      icon = Icons.directions_walk;
      label = '模拟走到图书馆';
      action = onExplore;
      enabled = actionEnabled;
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mapContentSide,
        AppSpacing.base * 3.5,
        AppSpacing.mapContentSide,
        AppSpacing.base * 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 19, color: AppColors.primary),
              const SizedBox(width: AppSpacing.base + 1),
              Text(
                locationLabel,
                style: const TextStyle(
                  fontSize: AppFontSizes.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '收集 $collected / $totalSpecies',
                style: const TextStyle(
                  fontSize: AppFontSizes.secondary,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base * 3),

          Text(
            description,
            style: const TextStyle(
              fontSize: AppFontSizes.secondary,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.base * 4),

          PrimaryButton(
            label: label,
            icon: icon,
            onPressed: enabled ? action : null,
          ),
        ],
      ),
    );
  }
}

/// 地图上的小标签：图标 + 文字
class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: AppSpacing.base),
        Text(
          text,
          style: const TextStyle(
            fontSize: AppFontSizes.secondary,
            color: AppColors.text,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
