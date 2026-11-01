import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/location_provider.dart';
import '../core/tokens.dart';
import '../models/sprite.dart';
import '../widgets/error_banner.dart';
import '../widgets/sprite_detail_sheet.dart';
import '../widgets/task_sheet.dart';
import 'bag_page.dart';
import 'capture_page.dart';
import 'dex_page.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'study/study_page.dart';

/// App 外壳：**全局状态机** + 底部导航 + 四个页面。
///
/// 为什么状态放在这里而不是各页面里：
/// 「有没有精灵出现」「有没有捕获」这四个页面都要用——地图页据此换按钮，
/// 图鉴页据此亮格子，背包页据此决定空态。状态只有一份，放在共同祖先里，
/// 四个页面都只是「接收状态 + 回调」的无状态组件。
///
/// 用 `IndexedStack` 而不是直接换 widget：四个页面常驻内存，切 tab 不丢滚动位置。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final Api _api = Api();
  final LocationProvider _location = DemoLocationProvider();

  /// 当前 tab：0 地图 / 1 图鉴 / 2 我的精灵 / 3 我的
  int _tab = 0;

  /// 全局加载态。**初值必须是 true**：首帧就要显示进度条，
  /// 否则会闪一下「按钮可点」的假象。
  bool _busy = true;

  /// 后端已连上（会话建好 + hello 拿到）。没就绪前地图主按钮是灰的。
  bool _ready = false;

  /// 精灵是否已出现在地图上。**由后端驱动**——服务端算的是 `nearby && !captured`，
  /// 所以捕获后它会自动变回 false。
  bool _nearby = false;

  /// 是否已捕获。同样由后端驱动。
  bool _captured = false;

  /// 任务模式是否进行中。纯客户端状态，跟后端无关。
  bool _task = false;

  /// 错误消息，非空时顶部显示横幅
  String? _error;

  /// 后端健康检查返回的文本
  String _hello = '正在连接后端';

  /// 已捕获种类数。**用后端返回的值**，不再像旧版那样本地写死 `captured ? 1 : 0`。
  int _collected = 0;

  /// 总种类数，同样来自后端
  int _totalSpecies = dexSlots.length;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  // ============================================================ 异步封装

  /// 所有网络操作都走这个包装。
  ///
  /// 它统一负责：开/关加载态、清空旧错误、把异常转成错误横幅。
  /// 好处是业务方法里不用写 try/catch，异常也不会让 App 崩掉。
  Future<void> _action(Future<void> Function() job) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      // 会话失效时丢掉本地会话，这样「重试」会重新建会话而不是继续用失效的 id。
      // 旧版缺这一步，服务重启后怎么点重试都修不好。
      if (message.contains('会话已失效') || message.contains('会话已满')) {
        _api.forgetSession();
        _ready = false;
      }
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 确保有一个可用会话。没有就建，有就跳过。
  Future<void> _ensureSession() async {
    if (_ready && _api.session.isNotEmpty) return;
    await _api.connect();
    final hello = await _api.hello();
    if (!mounted) return;
    setState(() {
      _hello = hello;
      _ready = true;
    });
  }

  // ============================================================ 业务操作

  /// 启动时调一次：建会话 → 健康检查 → 拉状态
  Future<void> _connect() => _action(() async {
        await _ensureSession();
        await _refresh();
      });

  /// 拉最新状态。**故意不包在 `_action` 里**——它总是被别的操作在内部调用，
  /// 这样加载态能覆盖整个链路（包括从答题页返回后）。
  Future<void> _refresh() async {
    final state = await _api.request('demo/state');
    if (!mounted) return;
    setState(() {
      _nearby = state['nearby'] as bool? ?? false;
      _captured = state['captured'] as bool? ?? false;
      _collected = state['count'] as int? ?? 0;
      _totalSpecies = state['totalSpecies'] as int? ?? dexSlots.length;
    });
  }

  /// 模拟走到图书馆。位置是在请求**成功之后**才改的——
  /// 顺序反了会出现「报错了但位置已经变了」的不一致。
  Future<void> _explore() => _action(() async {
        await _api.request('demo/explore', body: <String, dynamic>{});
        await _location.moveToLibrary();
        await _refresh();
      });

  /// 遇见精灵：先向后端要题，再进答题页；回来后刷新状态
  Future<void> _capture() => _action(() async {
        final challenge = await _api.request(
          'capture/challenge',
          body: <String, dynamic>{'spawnId': 'library-001'},
        );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CapturePage(api: _api, challenge: challenge),
          ),
        );
        await _refresh();
      });

  /// 重新开始演示
  Future<void> _reset() => _action(() async {
        await _ensureSession();
        await _api.request('demo/reset', body: <String, dynamic>{});
        _location.reset();
        if (mounted) {
          setState(() {
            _task = false;
            _tab = 0;
          });
        }
        await _refresh();
      });

  /// 错误横幅上的「重试」。
  ///
  /// 只重建会话并刷新状态，**不重置演示进度**——
  /// 旧版这里走的是 reset()，会把用户已经捕获的精灵也清掉。
  void _retry() {
    _connect();
  }

  // ============================================================ 交互

  void _openTasks() {
    showTaskSheet(
      context,
      running: _task,
      onToggle: () => setState(() => _task = !_task),
      // 「快进至完成」复用 explore：等价于走到图书馆并刷新状态
      onFastForward: () {
        setState(() => _task = false);
        _explore();
      },
      onOpenStudySkeleton: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StudyPage()),
        );
      },
    );
  }

  void _openSpriteDetail() {
    showSpriteDetail(context, unlocked: _captured);
  }

  // ============================================================ 界面

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // bottom: false —— 底部由导航栏自己处理安全区
        bottom: false,
        child: Column(
          children: [
            if (_busy)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.divider,
              ),
            if (_error != null)
              ErrorBanner(
                message: _error!,
                onRetry: _retry,
                retryEnabled: !_busy,
              ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  MapPage(
                    locationLabel: _location.label,
                    nearby: _nearby,
                    captured: _captured,
                    taskRunning: _task,
                    actionEnabled: !_busy && _ready,
                    collected: _collected,
                    totalSpecies: _totalSpecies,
                    helloText: _hello,
                    onExplore: _explore,
                    onCapture: _capture,
                    onGoToDex: () => setState(() => _tab = 1),
                    onTasks: _openTasks,
                  ),
                  DexPage(
                    captured: _captured,
                    collected: _collected,
                    totalSpecies: _totalSpecies,
                    onOpenDetail: _openSpriteDetail,
                  ),
                  BagPage(
                    captured: _captured,
                    count: _collected,
                    onOpenDetail: _openSpriteDetail,
                  ),
                  ProfilePage(
                    collected: _collected,
                    totalSpecies: _totalSpecies,
                    taskRunning: _task,
                    helloText: _hello,
                    busy: _busy,
                    onReset: _reset,
                    onTasks: _openTasks,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.navigationHeight,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _buildNavItem(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _items[index];
    final selected = index == _tab;
    final color = selected ? AppColors.primary : AppColors.secondaryText;

    return InkWell(
      onTap: () => setState(() => _tab = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 选中时图标底加一层浅主色胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(item.icon, size: 22, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: AppFontSizes.secondary,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static const _items = <_NavItem>[
    _NavItem(icon: Icons.explore_outlined, label: '地图'),
    _NavItem(icon: Icons.menu_book_outlined, label: '图鉴'),
    _NavItem(icon: Icons.inventory_2_outlined, label: '我的精灵'),
    _NavItem(icon: Icons.person_outline, label: '我的'),
  ];
}

/// 一个导航项的数据：图标 + 文字
class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
