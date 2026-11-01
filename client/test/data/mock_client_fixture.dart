import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'test_support.dart';

/// 常用 MockClient 构造，避免每个用例重复写请求体断言。
class MockClientFixture {
  MockClientFixture._();

  static MockClient challenge() => MockClient(
        (request) async => jsonResponse(fixture('07-challenge.json')),
      );

  static MockClient answerCorrect() => MockClient(
        (request) async => jsonResponse(fixture('08-answer.json')),
      );

  static MockClient answerWrong() => MockClient(
        (request) async => jsonResponse(fixture('answer-wrong.json')),
      );

  static MockClient statusCaptured() => MockClient(
        (request) async => jsonResponse(fixture('challenge-captured.json')),
      );

  static MockClient statusOpen() => MockClient(
        (request) async => jsonResponse(fixture('challenge-open.json')),
      );

  static MockClient statusExpired() => MockClient(
        (request) async => jsonResponse(fixture('challenge-expired.json')),
      );

  static MockClient envelopeOf(Map<String, dynamic> data) => MockClient(
        (request) async => envelope(data),
      );

  static MockClient echoWithHeaderCheck(
    Map<String, dynamic> data, {
    void Function(http.Request request)? onRequest,
  }) =>
      MockClient((request) async {
        onRequest?.call(request);
        return envelope(data);
      });

  static Map<String, dynamic> decodeBody(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;
}
