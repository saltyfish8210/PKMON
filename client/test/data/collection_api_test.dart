import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/api/collection_api.dart';

import 'test_support.dart';

void main() {
  group('HttpCollectionApi', () {
    test('概览解析三个数量', () async {
      final api = HttpCollectionApi(clientWith(MockClient(
        (request) async => jsonResponse(fixture('10-summary.json')),
      )));
      final summary = await api.summary();
      expect(summary.collectedSpeciesCount, 1);
      expect(summary.totalSpeciesCount, 1);
      expect(summary.captureCount, 1);
    });

    test('空收藏解析为 0', () async {
      final api = HttpCollectionApi(clientWith(MockClient(
        (request) async => jsonResponse(fixture('collection-empty.json')),
      )));
      final summary = await api.summary();
      expect(summary.collectedSpeciesCount, 0);
      expect(summary.captureCount, 0);
    });

    test('负数数量视为契约违约', () async {
      final api = HttpCollectionApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'collectedSpeciesCount': -1,
          'totalSpeciesCount': 3,
          'captureCount': 0,
        }),
      )));
      await expectLater(
        api.summary(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.protocol)),
      );
    });
  });
}
