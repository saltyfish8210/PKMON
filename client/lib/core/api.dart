import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// 后端接口封装。
///
/// 后端是课程 Demo 用的 Spring Boot 服务（`Demo运行包/pkmon-demo.jar`），
/// 所有业务接口统一前缀 `/api/v1`，响应外层是 `{code, message, data}`。
///
/// 移植自旧版 Web 客户端的 `client/lib/data/api.dart`，改动了两处：
/// 1. baseUrl 固定走安卓地址（旧版优先取浏览器地址，安卓上用不了）
/// 2. 会话失效时提供 `forgetSession()`，供上层重新建会话
class Api {
  Api({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 会话 id。由 `demo/sessions` 下发，之后每个请求都带在 `X-Demo-Session` 头里。
  /// 后端靠它区分不同演示会话的状态。
  String session = '';

  /// 请求超时。局域网够用；后端冷启动时偶尔会紧，可以调大。
  static const _timeout = Duration(seconds: 8);

  /// 安卓端的默认后端地址。
  ///
  /// **为什么是 10.0.2.2 而不是 127.0.0.1**：
  /// 安卓模拟器里，`127.0.0.1` 指的是**模拟器自己**；`10.0.2.2` 才是模拟器
  /// 对「宿主机（也就是你这台电脑）」的固定别名。
  ///
  /// 用真机演示时，后端在电脑上，得用电脑的局域网 IP：
  /// ```
  /// flutter run --dart-define=API_BASE=http://192.168.1.5:4180
  /// ```
  static const _androidEmulatorBase = 'http://10.0.2.2:4180';

  /// 后端地址。三种情况：
  ///
  /// 1. 编译时传了 `--dart-define=API_BASE=...` → 用传进来的（真机演示用这个）
  /// 2. **网页版** → 用当前页面的地址。因为网页和后端是**同一个服务**托管的，
  ///    直接取同源地址最省事，而且天然不需要后端配 CORS
  /// 3. **安卓** → `10.0.2.2:4180`
  String get base => defaultBase;

  static String get defaultBase {
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return Uri.base.origin;
    return _androidEmulatorBase;
  }

  /// 发一个业务请求，返回信封里的 `data`。
  ///
  /// 失败统一抛 `Exception(后端给的 message)`，由调用方（`action()`）捕获后显示。
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$base/api/v1/$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (session.isNotEmpty) 'X-Demo-Session': session,
    };

    // 有 body 用 POST，没有用 GET —— 沿用旧版约定
    final http.Response response;
    try {
      response = await (body == null
              ? _client.get(uri, headers: headers)
              : _client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('请求超时。请确认后端服务已启动。');
    } on Exception {
      // 连不上后端时 http 包会抛 ClientException / SocketException，
      // 原文是一长串英文加 errno，直接显示在界面上很难看也看不懂。
      // 这里统一换成一句人话——旧版没做这层处理，错误横幅里全是原始异常。
      throw Exception('连不上后端服务。请在 Demo运行包 里双击「启动PKMon.cmd」后再试。');
    }

    // 必须用 bodyBytes 手动 utf8 解码，不能用 response.body。
    // response.body 依赖响应头里的 charset，后端声明不完整时中文题干会乱码。
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode != 200 || json['code'] != 0) {
      throw Exception(json['message'] ?? '服务暂不可用');
    }
    return Map<String, dynamic>.from(json['data'] as Map);
  }

  /// 建会话。App 启动时调一次，拿到 sessionId。
  Future<void> connect() async {
    // 建会话本身不需要会话头，所以先清空，避免带着失效的旧 id 去建新会话
    session = '';
    final data = await request('demo/sessions', body: <String, dynamic>{});
    session = data['sessionId'] as String;
  }

  /// 丢会话。收到「会话已失效」类错误后调用，
  /// 上层据此重新走 [connect]，光重试原请求是修不好的。
  void forgetSession() {
    session = '';
  }

  /// 健康检查。`/test/hello` 返回纯文本，不走 `{code,message,data}` 信封。
  Future<String> hello() async {
    try {
      final response = await _client
          .get(Uri.parse('$base/test/hello'))
          .timeout(_timeout);
      final text = utf8.decode(response.bodyBytes);
      return text.split('\n').first.trim();
    } on TimeoutException {
      throw Exception('请求超时。请确认后端服务已启动。');
    } on Exception {
      throw Exception('连不上后端服务。请在 Demo运行包 里双击「启动PKMon.cmd」后再试。');
    }
  }

  void close() => _client.close();
}
