import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/location/location_provider.dart';
import '../../core/location/location_sample.dart';
import '../../core/location/simulated_location_provider.dart';
import 'fake_study_api.dart';
import 'study_api.dart';

/// 界面可见状态：只反映 API/Fake 响应，禁止本地判奖。
class TaskViewState {
  const TaskViewState({
    this.task,
    this.lastError,
    this.listening = false,
    this.simulated = true,
  });

  final TaskSnapshot? task;
  final String? lastError;
  final bool listening;
  final bool simulated;

  String get status => task?.status ?? 'IDLE';
  int get effectiveSeconds => task?.effectiveSeconds ?? 0;
  int get requiredSeconds => task?.requiredSeconds ?? 0;
  String? get spawnId => task?.spawnId;
  String? get pauseReason => task?.pauseReason;
}

/// 编排开始/采样上传/结束；不计本地奖励。
class StudyController extends ChangeNotifier {
  StudyController({
    required this._api,
    required this._location,
    this.regionId = 'library_entrance',
  });

  final StudyApi _api;
  final LocationProviderPort _location;
  final String regionId;

  StreamSubscription<LocationSample>? _sampleSub;
  StreamSubscription<LocationError>? _errorSub;
  TaskViewState _view = const TaskViewState();
  String? _createRequestId;
  bool _disposed = false;

  TaskViewState get view => _view;

  FakeStudyApi? get fakeApi => _api is FakeStudyApi ? _api : null;

  Future<void> startStudy({String locationSource = 'SIMULATED'}) async {
    _setError(null);
    _createRequestId = _newId();
    try {
      final snap = await _api.createTask(
        regionId: regionId,
        requestId: _createRequestId!,
        locationSource: locationSource,
      );
      _view = TaskViewState(
        task: snap,
        simulated: locationSource == 'SIMULATED' || _api is FakeStudyApi,
        listening: false,
      );
      notifyListeners();

      await _sampleSub?.cancel();
      await _errorSub?.cancel();
      _sampleSub = _location.samples.listen(_onSample, onError: (Object e) {
        _setError(e.toString());
      });
      _errorSub = _location.errors.listen((err) {
        _setError('${err.code}: ${err.message}');
        _view = TaskViewState(
          task: _view.task,
          lastError: _view.lastError,
          listening: false,
          simulated: _view.simulated,
        );
        notifyListeners();
      });

      await _location.start();
      _view = TaskViewState(
        task: _view.task,
        lastError: _view.lastError,
        listening: true,
        simulated: _view.simulated,
      );
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _onSample(LocationSample sample) async {
    final task = _view.task;
    if (task == null || task.status == 'ENDED') return;
    try {
      final snap = await _api.uploadSample(taskId: task.taskId, sample: sample);
      // 只接受 API 返回的状态，绝不本地伪造 TRIGGERED
      _view = TaskViewState(
        task: snap,
        lastError: snap.sampleAccepted == false
            ? '样本未接受: ${snap.rejectionReason}'
            : _view.lastError,
        listening: _view.listening,
        simulated: _view.simulated,
      );
      notifyListeners();
    } catch (e) {
      // 断网等：不把本地状态改成 TRIGGERED
      _setError('上传失败（本地不计奖）: $e');
    }
  }

  Future<void> endStudy() async {
    final task = _view.task;
    await _location.stop();
    await _sampleSub?.cancel();
    _sampleSub = null;
    await _errorSub?.cancel();
    _errorSub = null;

    if (task != null && task.status != 'ENDED') {
      try {
        final snap = await _api.endTask(
          taskId: task.taskId,
          requestId: _newId(),
        );
        _view = TaskViewState(
          task: snap,
          listening: false,
          simulated: _view.simulated,
        );
        notifyListeners();
      } catch (e) {
        _setError(e.toString());
      }
    } else {
      _view = TaskViewState(
        task: task,
        listening: false,
        simulated: _view.simulated,
        lastError: _view.lastError,
      );
      notifyListeners();
    }
  }

  Future<void> retryPermission() async {
    _setError(null);
    await _location.start();
    _view = TaskViewState(
      task: _view.task,
      listening: true,
      simulated: _view.simulated,
    );
    notifyListeners();
  }

  void _setError(String? message) {
    _view = TaskViewState(
      task: _view.task,
      lastError: message,
      listening: _view.listening,
      simulated: _view.simulated,
    );
    notifyListeners();
  }

  String _newId() =>
      'req-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(() async {
      await _location.stop();
      await _sampleSub?.cancel();
      await _errorSub?.cancel();
      final loc = _location;
      if (loc is SimulatedLocationProvider) {
        await loc.dispose();
      }
    }());
    super.dispose();
  }
}
