import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/api_client.dart';
import 'package:pkmon_app/data/api/token_provider.dart';

/// 固定样例：与《配套模板与样例/fixtures》同名文件一致，复制在 test/fixtures/。
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

http.Response jsonResponse(Object payload, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(payload)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

http.Response envelope(Object? data, {int code = 0, String message = 'ok'}) =>
    jsonResponse(<String, dynamic>{
      'code': code,
      'message': message,
      'data': data,
    });

ApiClient clientWith(
  MockClient mock, {
  TokenProvider? tokens,
  void Function()? onUnauthorized,
  Duration timeout = const Duration(seconds: 10),
}) =>
    ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:4180'),
      tokens: tokens ?? StaticTokenProvider(token: 'test-token', generation: 1),
      httpClient: mock,
      onUnauthorized: onUnauthorized,
      timeout: timeout,
    );
