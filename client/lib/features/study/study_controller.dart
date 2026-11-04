import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/location/location_provider.dart';
import '../../core/location/location_sample.dart';
import '../../data/api/request_id.dart';
import 'study_api.dart';

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

class StudyController extends ChangeNotifier {
  StudyController({
    required this._api,
    required LocationProviderPort location,
    this._device,
    this.regionId = 'library_entrance',
  }) : _simulation = location;

  final StudyApi _api;
  final LocationProviderPort _simulation;
  final LocationProviderPort? _device;
  final String regionId;
  LocationProviderPort? _location;
  StreamSubscription<LocationSample>? _samples;
  StreamSubscription<LocationError>? _errors;
  Timer? _poll;
  Timer? _noFix;
  TaskSnapshot? _task;
  String? _error;
  bool _listening = false, _simulated = true, _closed = false, _busy = false;
  int _epoch = 0;
  Future<void> _request = Future.value();
  String? _startKey, _endKey;
  bool get busy => _busy;
  TaskViewState get view => TaskViewState(
    task: _task,
    lastError: _error,
    listening: _listening,
    simulated: _simulated,
  );
  bool get active => _task != null && _task!.status != 'ENDED';
  void _emit() {
    if (!_closed) notifyListeners();
  }

  Future<void> _action(Future<void> Function() work) async {
    if (_busy || _closed) return;
    _busy = true;
    _error = null;
    _emit();
    try {
      await work();
    } catch (e) {
      _error = e.toString();
    } finally {
      _busy = false;
      _emit();
    }
  }

  Future<void> restore() => _action(() async {
    _task = await _api.getCurrent();
    _simulated = _task?.locationSource != 'GPS';
  });

  Future<void> startStudy({String locationSource = 'SIMULATED'}) =>
      _action(() async {
        if (_listening || _task?.status == 'TRIGGERED') return;
        final epoch = ++_epoch;
        _simulated = active ? _simulated : locationSource == 'SIMULATED';
        final provider = _simulated ? _simulation : _device;
        if (provider == null) throw StateError('当前设备不支持定位');
        _location = provider;
        await _samples?.cancel();
        await _errors?.cancel();
        if (_closed || _epoch != epoch) return;
        _errors = provider.errors.listen((e) {
          if (_closed || epoch != _epoch) return;
          _error = e.message;
          _listening = false;
          _emit();
        });
        _samples = provider.samples.listen((sample) {
          if (_closed || epoch != _epoch || !_listening || _busy) return;
          _noFix?.cancel();
          _sync(
            epoch,
            () => _api.uploadSample(taskId: _task!.taskId, sample: sample),
          );
        });
        try {
          await provider.start();
          if (_closed || _epoch != epoch) {
            await provider.stop();
            return;
          }
          if (!active) {
            _startKey ??= defaultRequestIdGenerator();
            _task = await _api.createTask(
              regionId: regionId,
              requestId: _startKey!,
              locationSource: _simulated ? 'SIMULATED' : 'GPS',
            );
            _startKey = null;
          }
          if (_closed || _epoch != epoch) {
            await provider.stop();
            return;
          }
          _listening = _error == null && _task?.status != 'TRIGGERED';
          if (!_listening) await provider.stop();
          _noFix?.cancel();
          if (_listening) {
            _noFix = Timer(const Duration(seconds: 15), () {
              if (epoch == _epoch && _listening) {
                _error = '仍未收到可用位置，请检查定位服务或尝试到室外采样';
                _emit();
              }
            });
          }
          _poll?.cancel();
          _poll = Timer.periodic(const Duration(seconds: 5), (_) {
            if (!_busy && active && _task?.status != 'TRIGGERED') {
              _sync(epoch, _api.getCurrent);
            }
          });
        } catch (_) {
          await provider.stop();
          rethrow;
        }
      });

  bool _inFlight = false;
  void _sync(int epoch, Future<TaskSnapshot?> Function() fetch) {
    if (_inFlight || _closed || epoch != _epoch) return;
    _inFlight = true;
    _request = () async {
      try {
        final next = await fetch();
        if (_closed || epoch != _epoch) return;
        _task = next;
        if (next?.sampleAccepted == false) {
          _error = '样本未采纳：${next?.rejectionReason}';
        } else if (next?.sampleAccepted == true) {
          _error = null;
        }
        if (!active || next?.status == 'TRIGGERED') await pauseSampling();
      } catch (e) {
        if (epoch == _epoch) _error = e.toString();
      } finally {
        _inFlight = false;
        _emit();
      }
    }();
  }

  Future<void> pauseSampling() async {
    ++_epoch;
    _poll?.cancel();
    _listening = false;
    _noFix?.cancel();
    final samples = _samples, errors = _errors;
    _samples = null;
    _errors = null;
    await _location?.stop();
    await samples?.cancel();
    await errors?.cancel();
    _emit();
  }

  Future<void> endStudy() => _action(() async {
    await pauseSampling();
    await _request;
    if (active) {
      _endKey ??= defaultRequestIdGenerator();
      _task = await _api.endTask(taskId: _task!.taskId, requestId: _endKey!);
      _endKey = null;
    }
  });

  Future<void> retryPermission() =>
      startStudy(locationSource: _simulated ? 'SIMULATED' : 'GPS');

  @override
  void dispose() {
    _closed = true;
    unawaited(
      pauseSampling().then((_) async {
        await _simulation.dispose();
        await _device?.dispose();
      }),
    );
    super.dispose();
  }
}
