import 'package:flutter/foundation.dart';

import '../../data/api/api_failure.dart';
import '../../data/api/capture_api.dart';
import '../../data/api/collection_api.dart';
import '../../data/api/request_id.dart';
import '../../data/model/capture_models.dart';
import '../../data/model/collection_models.dart';

sealed class CaptureUiState {
  const CaptureUiState();
}

class CaptureIdle extends CaptureUiState {
  const CaptureIdle();
}

class CaptureLoading extends CaptureUiState {
  const CaptureLoading();
}

class CaptureReady extends CaptureUiState {
  const CaptureReady({
    required this.challenge,
    this.lastError,
    this.lastResultWasWrong = false,
  });

  final ChallengeView challenge;
  final String? lastError;
  final bool lastResultWasWrong;
}

class CaptureSubmitting extends CaptureUiState {
  const CaptureSubmitting(this.challenge);

  final ChallengeView challenge;
}

class CaptureUnknown extends CaptureUiState {
  const CaptureUnknown({this.message = '结果待确认，请重新确认或稍后重试'});

  final String message;
}

class CaptureCaptured extends CaptureUiState {
  const CaptureCaptured({required this.captureRecordId, this.summary});

  final String captureRecordId;
  final CollectionSummary? summary;
}

class CaptureExpired extends CaptureUiState {
  const CaptureExpired(this.message);

  final String message;
}

class CaptureFailed extends CaptureUiState {
  const CaptureFailed(this.message, {this.retryable = true});

  final String message;
  final bool retryable;
}

/// 一次答题的编排与状态机。
///
/// 不变式：
/// - requestId 只由本类生成，页面无法传入；
/// - 同一次提交的恢复重试复用原 requestId + 原 optionId；
/// - 用户重新作答必须生成新 requestId；
/// - 只有 result=CORRECT 且 captureRecordId 非空才进入 [CaptureCaptured]。
class CaptureController {
  CaptureController({
    required this.captureApi,
    required this.collectionApi,
    this.newRequestId = defaultRequestIdGenerator,
  });

  final CaptureApi captureApi;
  final CollectionApi collectionApi;
  final RequestIdGenerator newRequestId;

  final ValueNotifier<CaptureUiState> _state =
      ValueNotifier<CaptureUiState>(const CaptureIdle());

  ValueListenable<CaptureUiState> get state => _state;

  ChallengeView? _challenge;
  String? _spawnId;
  String? _requestId;
  String? _optionId;
  bool _sending = false;
  bool _disposed = false;

  /// 仅供测试断言：当前保留的请求标识（成功后也不清空）。
  @visibleForTesting
  String? get currentRequestId => _requestId;

  Future<void> load(String spawnId) async {
    if (_disposed) return;
    _spawnId = spawnId;
    _challenge = null;
    _requestId = null;
    _optionId = null;
    _emit(const CaptureLoading());
    try {
      final view = await captureApi.challenge(spawnId: spawnId);
      if (_disposed) return;
      _challenge = view;
      _emit(CaptureReady(challenge: view));
    } on ApiFailure catch (failure) {
      if (_disposed) return;
      _emit(_loadFailure(failure));
    } on Exception {
      if (_disposed) return;
      _emit(const CaptureFailed('加载题目失败，请重试'));
    }
  }

  Future<void> submit(String optionId) async {
    final challenge = _challenge;
    if (_disposed || challenge == null || _sending) return;
    if (challenge.optionById(optionId) == null) {
      _emit(CaptureReady(challenge: challenge, lastError: '请选择有效选项'));
      return;
    }
    _sending = true;
    _requestId = newRequestId();
    _optionId = optionId;
    _emit(CaptureSubmitting(challenge));
    try {
      final result = await captureApi.answer(
        challengeId: challenge.challengeId,
        requestId: _requestId!,
        optionId: optionId,
      );
      if (_disposed) return;
      if (result.captured) {
        final summary = await _safeSummary();
        if (_disposed) return;
        _emit(CaptureCaptured(
          captureRecordId: result.captureRecordId!,
          summary: summary,
        ));
      } else {
        _emit(CaptureReady(challenge: challenge, lastResultWasWrong: true));
      }
    } on ApiFailure catch (failure) {
      if (_disposed) return;
      await _handleSubmitFailure(failure, challenge);
    } on Exception {
      if (_disposed) return;
      _emit(const CaptureFailed('提交失败，请重试'));
    } finally {
      _sending = false;
    }
  }

  /// 结果待确认或加载失败时的手动重试。
  Future<void> retry() async {
    if (_disposed) return;
    final current = _state.value;
    if (current is CaptureUnknown && _challenge != null) {
      await _recover();
      return;
    }
    final spawnId = _spawnId;
    if (spawnId != null && (current is CaptureFailed || current is CaptureIdle)) {
      await load(spawnId);
    }
  }

  Future<CollectionSummary?> refreshSummary() => _safeSummary();

  void dispose() {
    _disposed = true;
    _state.dispose();
  }

  Future<void> _handleSubmitFailure(
    ApiFailure failure,
    ChallengeView challenge,
  ) async {
    switch (failure.kind) {
      case FailureKind.timeout:
      case FailureKind.network:
        await _recover();
      case FailureKind.expired:
        _emit(CaptureExpired(failure.message));
      case FailureKind.unauthorized:
        _emit(const CaptureFailed('登录已失效，请重新登录', retryable: false));
      case FailureKind.staleSession:
        _emit(const CaptureUnknown(message: '会话已切换，结果已丢弃'));
      case FailureKind.badRequest:
      case FailureKind.conflict:
        _emit(CaptureReady(challenge: challenge, lastError: failure.message));
      case FailureKind.serviceUnavailable:
      case FailureKind.server:
        _emit(CaptureReady(
          challenge: challenge,
          lastError: '${failure.message}，可重试',
        ));
      case FailureKind.notFound:
        _emit(const CaptureFailed('该挑战已不存在，请返回地图重新遭遇'));
      case FailureKind.protocol:
        _emit(const CaptureFailed('服务返回数据异常，请重试'));
    }
  }

  Future<void> _recover() async {
    final challenge = _challenge;
    if (_disposed || challenge == null) return;
    _emit(const CaptureUnknown());
    try {
      final status = await captureApi.status(challengeId: challenge.challengeId);
      if (_disposed) return;
      switch (status.status) {
        case ChallengeStatusKind.captured:
          final summary = await _safeSummary();
          if (_disposed) return;
          _emit(CaptureCaptured(
            captureRecordId: status.captureRecordId!,
            summary: summary,
          ));
        case ChallengeStatusKind.expired:
          _emit(const CaptureExpired('挑战已过期，请返回地图重新遭遇'));
        case ChallengeStatusKind.open:
          await _retryOriginalAnswer(challenge);
      }
    } on ApiFailure catch (failure) {
      if (_disposed) return;
      if (failure.kind == FailureKind.unauthorized) {
        _emit(const CaptureFailed('登录已失效，请重新登录', retryable: false));
      } else {
        _emit(CaptureUnknown(message: failure.message));
      }
    } on Exception {
      if (_disposed) return;
      _emit(const CaptureUnknown());
    }
  }

  Future<void> _retryOriginalAnswer(ChallengeView challenge) async {
    final requestId = _requestId;
    final optionId = _optionId;
    if (requestId == null || optionId == null) {
      _emit(CaptureReady(
        challenge: challenge,
        lastError: '结果待确认，请重新作答',
      ));
      return;
    }
    try {
      final result = await captureApi.answer(
        challengeId: challenge.challengeId,
        requestId: requestId,
        optionId: optionId,
      );
      if (_disposed) return;
      if (result.captured) {
        final summary = await _safeSummary();
        if (_disposed) return;
        _emit(CaptureCaptured(
          captureRecordId: result.captureRecordId!,
          summary: summary,
        ));
      } else {
        _emit(CaptureReady(challenge: challenge, lastResultWasWrong: true));
      }
    } on ApiFailure catch (failure) {
      if (_disposed) return;
      switch (failure.kind) {
        case FailureKind.expired:
          _emit(const CaptureExpired('挑战已过期，请返回地图重新遭遇'));
        case FailureKind.timeout:
        case FailureKind.network:
        case FailureKind.serviceUnavailable:
        case FailureKind.server:
          _emit(CaptureUnknown(message: failure.message));
        case FailureKind.unauthorized:
          _emit(const CaptureFailed('登录已失效，请重新登录', retryable: false));
        default:
          _emit(CaptureReady(challenge: challenge, lastError: failure.message));
      }
    }
  }

  Future<CollectionSummary?> _safeSummary() async {
    try {
      return await collectionApi.summary();
    } on ApiFailure {
      return null;
    }
  }

  CaptureUiState _loadFailure(ApiFailure failure) => switch (failure.kind) {
        FailureKind.unauthorized =>
          const CaptureFailed('登录已失效，请重新登录', retryable: false),
        FailureKind.expired => CaptureExpired(failure.message),
        FailureKind.notFound => const CaptureFailed('该遭遇不存在，请返回地图'),
        FailureKind.serviceUnavailable =>
          const CaptureFailed('服务暂不可用，请稍后重试'),
        FailureKind.protocol =>
          const CaptureFailed('服务返回数据异常，请重试'),
        _ => CaptureFailed('${failure.message}，请重试'),
      };

  void _emit(CaptureUiState next) {
    if (_disposed) return;
    _state.value = next;
  }
}
