import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/api_failure.dart';
import 'package:pkmon_app/data/api/collection_detail_api.dart';

import 'test_support.dart';

void main() {
  group('HttpCollectionDetailApi', () {
    test('图鉴解析条目、名称与首次收录时刻', () async {
      final api = HttpCollectionDetailApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'collectedSpeciesCount': 1,
          'totalSpeciesCount': 1,
          'entries': [
            {
              'speciesId': 'siege_lion',
              'name': '攻城狮',
              'count': 2,
              'firstCapturedAt': '2026-11-16T02:00:00Z',
            },
          ],
        }),
      )));
      final dex = await api.dex();
      expect(dex.collectedSpeciesCount, 1);
      expect(dex.totalSpeciesCount, 1);
      expect(dex.entries, hasLength(1));
      expect(dex.entries.first.name, '攻城狮');
      expect(dex.entries.first.count, 2);
      expect(dex.entries.first.captured, isTrue);
      expect(dex.entries.first.firstCapturedAt,
          DateTime.parse('2026-11-16T02:00:00Z'));
    });

    test('图鉴未解锁条目：count 为 0 且首次时刻为空', () async {
      final api = HttpCollectionDetailApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'collectedSpeciesCount': 0,
          'totalSpeciesCount': 1,
          'entries': [
            {
              'speciesId': 'siege_lion',
              'name': '攻城狮',
              'count': 0,
              'firstCapturedAt': null,
            },
          ],
        }),
      )));
      final dex = await api.dex();
      expect(dex.entries.single.captured, isFalse);
      expect(dex.entries.single.firstCapturedAt, isNull);
    });

    test('背包解析数量与倒序条目', () async {
      final api = HttpCollectionDetailApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'totalCount': 3,
          'speciesCount': 2,
          'entries': [
            {
              'speciesId': 'siege_lion',
              'name': '攻城狮',
              'count': 2,
              'latestCapturedAt': '2026-11-16T03:00:00Z',
            },
            {
              'speciesId': 'library_fox',
              'name': '图书馆狐',
              'count': 1,
              'latestCapturedAt': '2026-11-16T02:00:00Z',
            },
          ],
        }),
      )));
      final bag = await api.bag();
      expect(bag.totalCount, 3);
      expect(bag.speciesCount, 2);
      expect(bag.entries.first.speciesId, 'siege_lion');
      expect(bag.entries.first.count, 2);
    });

    test('背包条目数量非正视为契约违约', () async {
      final api = HttpCollectionDetailApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'totalCount': 0,
          'speciesCount': 1,
          'entries': [
            {
              'speciesId': 'siege_lion',
              'name': '攻城狮',
              'count': 0,
              'latestCapturedAt': null,
            },
          ],
        }),
      )));
      await expectLater(
        api.bag(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.protocol)),
      );
    });

    test('图鉴 entries 不是数组视为契约违约', () async {
      final api = HttpCollectionDetailApi(clientWith(MockClient(
        (request) async => envelope(<String, dynamic>{
          'collectedSpeciesCount': 0,
          'totalSpeciesCount': 1,
          'entries': 'oops',
        }),
      )));
      await expectLater(
        api.dex(),
        throwsA(isA<ApiFailure>()
            .having((e) => e.kind, 'kind', FailureKind.protocol)),
      );
    });
  });
}
