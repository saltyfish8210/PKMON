import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/features/auth/session_store.dart';
import 'package:pkmon_app/features/auth/session_token_provider.dart';

import '../../support/auth_test_helpers.dart';

void main() {
  test('保存与读取会话，代次递增', () async {
    final store = InMemorySessionStore();
    final before = store.generation;

    await store.save(testSession(token: 'abc'));

    expect((await store.load())?.token, 'abc');
    expect(store.generation, before + 1);
  });

  test('清除会话后代次递增且读取为空', () async {
    final store = InMemorySessionStore(initial: testSession());
    final before = store.generation;

    await store.clear();

    expect(await store.load(), isNull);
    expect(store.generation, before + 1);
  });

  test('SessionTokenProvider 提供 token 与代次，清除后为空', () async {
    final store = InMemorySessionStore(initial: testSession(token: 'abc'));
    final provider = SessionTokenProvider(store);

    final token = await provider.current();
    expect(token?.value, 'abc');
    expect(token?.generation, store.generation);

    await store.clear();
    expect(await provider.current(), isNull);
  });
}
