import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/location/device_location_provider.dart';
import '../../core/location/simulated_location_provider.dart';
import '../../data/api/api_client.dart';
import '../../data/api/capture_api.dart';
import '../../data/api/collection_api.dart';
import '../capture/capture_controller.dart';
import '../capture/capture_page.dart';
import 'fake_study_api.dart';
import 'study_api.dart';
import 'study_controller.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key, this.client});
  final ApiClient? client;
  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> with WidgetsBindingObserver {
  late final StudyController controller;
  bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get online => widget.client != null;
  bool opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final client = widget.client;
    controller = StudyController(
      api: client == null ? FakeStudyApi() : HttpStudyApi(client),
      location: SimulatedLocationProvider(interval: const Duration(seconds: 3)),
      device: android && online ? DeviceLocationProvider() : null,
    );
    unawaited(controller.restore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(controller.pauseSampling());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> openChallenge(String spawn) async {
    if (opening) return;
    setState(() => opening = true);
    final client = widget.client!;
    final capture = CaptureController(
      captureApi: HttpCaptureApi(client),
      collectionApi: HttpCollectionApi(client),
    );
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CapturePage(returnLabel:'返回自习', spawnId: spawn, controller: capture),
        ),
      );
    } finally {
      capture.dispose();
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('自习任务')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final v = controller.view;
        final active = controller.active;
        final ready = v.spawnId != null && v.status == 'TRIGGERED';
        final start = !controller.busy && !v.listening && !ready;
        const labels = {
          'IDLE': '未开始',
          'WAITING': '等待进入区域',
          'DWELLING': '驻留中',
          'PAUSED': '已暂停',
          'TRIGGERED': '已出现精灵',
          'ENDED': '已结束',
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              online ? '自习进度由服务端保存到本次运行。' : '离线模拟练习 · 登录后可进入答题',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text('状态　${labels[v.status] ?? v.status}'),
            Text('有效驻留　${v.effectiveSeconds} / ${v.requiredSeconds} 秒'),
            if (active) Text(v.simulated ? '位置来源　课堂模拟样本' : '位置来源　设备定位'),
            if (v.pauseReason != null) Text('暂停原因　${v.pauseReason}'),
            if (active && !ready) Text(v.listening ? '正在采样' : '采样已停止，可手动恢复'),
            if (v.lastError != null)
              Text(
                v.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            if (!active)
              FilledButton(
                onPressed: start ? () => controller.startStudy() : null,
                child: const Text('使用模拟位置开始'),
              ),
            if (!active && android && online)
              OutlinedButton(
                onPressed: start
                    ? () => controller.startStudy(locationSource: 'GPS')
                    : null,
                child: const Text('使用设备定位开始'),
              ),
            if (active && !v.listening && !ready)
              FilledButton(
                onPressed: start ? controller.retryPermission : null,
                child: const Text('恢复定位 / 重试'),
              ),
            if (ready && online)
              FilledButton(
                onPressed: opening ? null : () => openChallenge(v.spawnId!),
                child: const Text('前往答题'),
              ),
            if (ready && !online) const Text('模拟练习已达标。使用账号登录后可以挑战精灵。'),
            if (active)
              OutlinedButton(
                onPressed: controller.busy ? null : controller.endStudy,
                child: const Text('结束任务'),
              ),
          ],
        );
      },
    ),
  );
}
