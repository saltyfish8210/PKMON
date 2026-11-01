import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_failure.dart';
import 'token_provider.dart';

/// 附加请求头（旧演示用它携带 X-Demo-Session）。
typedef HeaderProvider = Map<String, String> Function();

/// 统一网络层：拼请求、注入 Bearer、解析 {code,message,data}、超时与错误映射。
///
/// 约定：
/// - 页面不直接使用本类，业务端口（AuthApi/CaptureApi/...）封装路径与 DTO；
/// - 本文件不 import features/*，也不打印 token、Authorization 或请求体；
/// - 响应到达后比较会话代次，账号切换后的迟到响应一律丢弃（staleSession）。
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
    this.onUnauthorized,
    this.extraHeaders,
    this.apiPrefix = '/api/v1',
  }) : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final TokenProvider tokens;
  final Duration timeout;

  /// 40101 时回调入口清会话；网络层自己不做跳转。
  final void Function()? onUnauthorized;
  final HeaderProvider? extraHeaders;
  final String apiPrefix;

  final http.Client _http;

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = true,
    Map<String, String>? query,
  }) =>
      _send('GET', path, authenticated: authenticated, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      ...?extraHeaders?.call(),
    };

    SessionToken? sentToken;
    if (authenticated) {
      sentToken = await tokens.current();
      if (sentToken == null || sentToken.value.isEmpty) {
        onUnauthorized?.call();
        throw const ApiFailure(FailureKind.unauthorized, '登录已失效，请重新登录',
            code: 40101);
      }
      headers['Authorization'] = 'Bearer ${sentToken.value}';
    }

    final http.Response response;
    try {
      final future = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(
              uri,
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode(body ?? const <String, dynamic>{}),
            );
      response = await future.timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(FailureKind.timeout, '请求超时，请稍后重试');
    } on http.ClientException {
      throw const ApiFailure(FailureKind.network, '连不上后端服务，请检查网络');
    } on Exception catch (error) {
      if (error is ApiFailure) rethrow;
      throw const ApiFailure(FailureKind.network, '连不上后端服务，请检查网络');
    }

    if (authenticated && sentToken != null) {
      final current = await tokens.current();
      if (current == null || current.generation != sentToken.generation) {
        throw const ApiFailure(FailureKind.staleSession, '会话已切换，已丢弃旧响应');
      }
    }

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw _statusFailure(response.statusCode);
    }
    if (decoded is! Map) {
      throw ApiFailure.protocol('响应不是 JSON 对象（HTTP ${response.statusCode}）');
    }
    final json = decoded.map((key, value) => MapEntry(key.toString(), value));
    final code = json['code'];
    if (code is! int) {
      throw ApiFailure.protocol('响应缺少 code');
    }
    final rawMessage = json['message'];
    final message = rawMessage is String ? rawMessage : '';
    if (code != 0) {
      throw _failureForCode(code, message, response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFailure(
        FailureKind.server,
        message.isEmpty ? '服务返回异常状态' : message,
        httpStatus: response.statusCode,
      );
    }
    final data = json['data'];
    if (data == null) return const <String, dynamic>{};
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw ApiFailure.protocol('响应 data 不是对象');
  }

  ApiFailure _failureForCode(int code, String message, int httpStatus) {
    final kind = switch (code) {
      40001 => FailureKind.badRequest,
      40101 => FailureKind.unauthorized,
      40401 => FailureKind.notFound,
      40901 || 40902 || 40903 || 40904 => FailureKind.conflict,
      41001 => FailureKind.expired,
      50301 || 50302 => FailureKind.serviceUnavailable,
      _ => FailureKind.server,
    };
    if (kind == FailureKind.unauthorized) onUnauthorized?.call();
    return ApiFailure(
      kind,
      message.isEmpty ? '服务返回错误码 $code' : message,
      code: code,
      httpStatus: httpStatus,
    );
  }

  ApiFailure _statusFailure(int httpStatus) {
    final kind = switch (httpStatus) {
      400 => FailureKind.badRequest,
      401 => FailureKind.unauthorized,
      404 => FailureKind.notFound,
      409 => FailureKind.conflict,
      410 => FailureKind.expired,
      503 => FailureKind.serviceUnavailable,
      _ => FailureKind.server,
    };
    if (kind == FailureKind.unauthorized) onUnauthorized?.call();
    return ApiFailure(kind, '服务返回 HTTP $httpStatus', httpStatus: httpStatus);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final base = baseUrl.toString();
    final trimmedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$trimmedBase$apiPrefix$normalizedPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  void close() => _http.close();
}
