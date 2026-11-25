import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../models/sprite.dart';
import '../data/model/collection_models.dart';
import '../widgets/error_banner.dart';
import '../data/api/api_client.dart';
import '../data/api/collection_api.dart';
import '../data/api/collection_detail_api.dart';
import 'collection/collection_page.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'study/study_page.dart';
import '../core/location/location_sample.dart';
import '../core/location/simulated_location_provider.dart';
import '../core/request_id.dart';
import '../data/api/capture_api.dart';
import '../data/api/study_api.dart';
import 'dart:async';
import '../data/model/study_models.dart';
import 'capture/capture_controller.dart';
import 'capture/capture_page.dart' as account_capture;

/// App 外壳：**全局状态机** + 底部导航 + 四个页面。
///
/// 为什么状态放在这里而不是各页面里：
/// 「有没有精灵出现」「有没有捕获」这四个页面都要用——地图页据此换按钮，
/// 图鉴页据此亮格子，背包页据此决定空态。状态只有一份，放在共同祖先里，
/// 四个页面都只是「接收状态 + 回调」的无状态组件。
///
/// 用 `IndexedStack` 而不是直接换 widget：四个页面常驻内存，切 tab 不丢滚动位置。
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.studyClient,
    this.accountClient,
    this.nickname,
    this.onLogout,
  });

  final ApiClient? studyClient;

  /// 已登录时注入的账号客户端：用于「我的收藏」与退出登录；演示模式为 null。
  final ApiClient? accountClient;

  /// 已登录用户昵称；演示模式为 null。
  final String? nickname;

  /// 退出登录回调；演示模式为 null。
  final Future<void> Function()? onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Map<String, dynamic>? _marker;
  DexView? _dex;
  BagView? _bag;
  int _tab = 0;

  static const String _studyRegion = 'library_entrance';
  SimulatedLocationProvider? _sim;
  StreamSubscription<LocationSample>? _simSub;
  String? _studyTaskId;
  String? _studyStatus;
  int _studyEffective = 0;
  int _studyRequired = 0;
  bool _studyOutside = false;
  bool _studyBusy = false;
  String? _capturedName;
  double _latitude = 39.9042;
  double _longitude = 116.4074;

  StudyApi? get _studyApi =>
      widget.accountClient == null ? null : HttpStudyApi(widget.accountClient!);

  /// 全局加载态。**初值必须是 true**：首帧就要显示进度条，
  /// 否则会闪一下「按钮可点」的假象。
  bool _busy = true;

  /// 错误消息，非空时顶部显示横幅
  String? _error;

  /// 后端健康检查返回的文本
  String get _hello => '账号收藏 · 模拟定位';

  /// 已捕获种类数。**用后端返回的值**，不再像旧版那样本地写死 `captured ? 1 : 0`。
  int _collected = 0;

  /// 总种类数，同样来自后端
  int _totalSpecies = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _simSub?.cancel();
    _sim?.dispose();
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
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _action(_refresh);

  Future<void> _refreshNearby(double latitude, double longitude) async {
    final client = widget.accountClient;
    if (client == null) return;
    _latitude = latitude;
    _longitude = longitude;
    final response = await client.get('/capture/nearby', query: {
      'lat': '$latitude', 'lng': '$longitude', 'radius': '200',
    });
    if (!mounted || latitude != _latitude || longitude != _longitude) return;
    final items = (response['items'] as List).cast<Map<String, dynamic>>();
    setState(() => _marker = items.isEmpty ? null : items.first);
  }

  Future<void> _refresh() async {
    final client = widget.accountClient;
    if (client == null) return;
    final detail = HttpCollectionDetailApi(client);
    final summary = await HttpCollectionApi(client).summary();
    final dex = await detail.dex();
    final bag = await detail.bag();
    await _refreshNearby(_latitude, _longitude);
    if (!mounted) return;
    setState(() {
      _collected = summary.collectedSpeciesCount;
      _totalSpecies = summary.totalSpeciesCount;
      _dex = dex;
      _bag = bag;
    });
  }

  /// 在地图上开始自习任务：创建任务 → 模拟样本持续上报 → 达标生成遭遇。
  Future<void> _startStudyOnMap() async {
    final api = _studyApi;
    if (api == null || _studyBusy) return;
    setState(() {
      _studyBusy = true;
      _error = null;
    });
    try {
      final snap = await api.createTask(
        regionId: _studyRegion,
        requestId: RequestId.generate(),
        locationSource: 'SIMULATED',
      );
      _sim ??= SimulatedLocationProvider(interval: const Duration(seconds: 3));
      _simSub ??= _sim!.samples.listen((sample) async {
        final id = _studyTaskId;
        if (id == null) return;
        try {
          final r = await api.uploadSample(
            taskId: id,
            sample: LocationSampleDto(
              sampleId: sample.sampleId,
              latitude: sample.latitude,
              longitude: sample.longitude,
              accuracyMeters: sample.accuracyMeters,
              sampledAt: sample.sampledAt,
              coordinateSystem: sample.coordinateSystem,
              source: 'SIMULATED',
            ),
          );
          if (!mounted) return;
          setState(() {
            _studyStatus = r.status;
            _studyEffective = r.effectiveSeconds;
            _studyRequired = r.requiredSeconds;

          });
          await _refreshNearby(sample.latitude, sample.longitude);
        } catch (_) {
          // 单条样本失败不影响后续上报
        }
      });
      await _sim!.start();
      if (!mounted) return;
      setState(() {
        _studyTaskId = snap.taskId;
        _studyStatus = snap.status;
        _studyEffective = snap.effectiveSeconds;
        _studyRequired = snap.requiredSeconds;
        _studyBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _studyBusy = false;
        _error = '开始自习失败：$e';
      });
    }
  }

  Future<void> _endStudyOnMap() async {
    final api = _studyApi;
    final id = _studyTaskId;
    if (api == null || id == null) return;
    try {
      await api.endTask(taskId: id, requestId: RequestId.generate());
    } catch (error) {
      if (mounted) setState(() => _error = '结束自习失败：$error');
      return;
    }
    await _sim?.stop();
    if (!mounted) return;
    setState(() {
      _studyTaskId = null;
      _studyStatus = null;
      _capturedName = null;

      _studyEffective = 0;
      _studyRequired = 0;
    });
  }

  void _setStudyOutside(bool outside) {
    _sim?.setOutside(outside);
    setState(() => _studyOutside = outside);
  }

  /// 遭遇生成后进入答题（真实接口）。
  Future<void> _openStudyChallenge() async {
    final client = widget.accountClient;
    final spawn = _marker?['spawnId'] as String?;
    final name = _marker?['name'] as String?;
    if (client == null || spawn == null) return;
    final controller = CaptureController(
      captureApi: HttpCaptureApi(client),
      collectionApi: HttpCollectionApi(client),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => account_capture.CapturePage(
          spawnId: spawn,
          controller: controller,
          returnLabel: '返回地图',
        ),
      ),
    );
    final captured = controller.state.value is CaptureCaptured;
    controller.dispose();
    if (!mounted) return;
    if (captured) setState(() => _capturedName = name);
    await _connect();
  }

  Widget _studyBanner(BuildContext context) {
    final status = switch (_studyStatus) {
      'DWELLING' => '驻留中',
      'PAUSED' => '已暂停',
      'TRIGGERED' => '遭遇已生成',
      'ENDED' => '已结束',
      _ => _studyStatus ?? '准备中',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('自习任务　$status　有效驻留 $_studyEffective / $_studyRequired 秒',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(_studyOutside ? '模拟位置：区域外' : '模拟位置：区域内',
              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setStudyOutside(true),
                child: const Text('演示：离开区域'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _setStudyOutside(false),
                child: const Text('回到区域'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _endStudyOnMap,
                child: const Text('结束自习'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _openTasks() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StudyPage(client: widget.studyClient)));
    if (mounted) await _connect();
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
                onRetry: _connect,
                retryEnabled: !_busy,
              ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  Stack(
                    children: [
                      MapPage(
                        locationLabel: _studyOutside ? '区域外（模拟）' : '图书馆入口（模拟）',
                        nearby: _marker != null,
                        captured: _marker == null && _studyTaskId != null && _capturedName != null,
                        taskRunning: _studyTaskId != null,
                        actionEnabled: !_busy && !_studyBusy && widget.accountClient != null,
                        collected: _collected,
                        totalSpecies: _totalSpecies,
                        helloText: _hello,
                        spriteAsset: _marker == null ? AppAssets.spiritPlaceholder : 'assets/sprites/${_marker!['iconKey']}.png',
                        spriteLabel: _marker?['name'] as String? ?? _capturedName ?? '附近精灵',
                        onExplore: _studyTaskId == null ? _startStudyOnMap : _connect,
                        onCapture: _openStudyChallenge,
                        onGoToDex: () => setState(() => _tab = 1),
                        onTasks: _openTasks,
                      ),
                      if (_studyTaskId != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: _studyBanner(context),
                        ),
                    ],
                  ),
                  ListView(children: [
                    ListTile(title: Text('图鉴 $_collected / $_totalSpecies')),
                    for (final entry in _dex?.entries ?? <DexEntry>[])
                      ListTile(leading: Image.asset(entry.imageKey, width: 44), title: Text('${entry.catalogNumber}. ${entry.name}'),
                          subtitle: Text(entry.description), trailing: Text(entry.captured ? '×${entry.count}' : '未收录')),
                  ]),
                  ListView(children: [
                    ListTile(title: Text('我的精灵 · ${_bag?.totalCount ?? 0} 只')),
                    for (final entry in _bag?.entries ?? <BagEntry>[])
                      ListTile(title: Text(entry.name), trailing: Text('×${entry.count}')),
                  ]),
                  ProfilePage(
                    collected: _collected,
                    totalSpecies: _totalSpecies,
                    taskRunning: _studyTaskId != null,
                    helloText: _hello,
                    busy: _busy,
                    onReset: _connect,
                    onTasks: _openTasks,
                    nickname: widget.nickname,
                    onOpenStudy: _openTasks,
                    onOpenCollection: widget.accountClient == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CollectionPage(
                                  api: HttpCollectionApi(widget.accountClient!),
                                  detail: HttpCollectionDetailApi(
                                    widget.accountClient!,
                                  ),
                                ),
                              ),
                            ),
                    onLogout: widget.onLogout,
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
