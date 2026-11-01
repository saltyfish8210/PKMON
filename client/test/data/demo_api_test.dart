import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pkmon_app/data/api/demo_api.dart';

import 'test_support.dart';

void main() {
  test('connect 后演示请求携带 X-Demo-Session，且不带 Bearer', () async {
    final requests = <http.Request>[];
    final api = DemoApi(
      baseUrl: Uri.parse('http://127.0.0.1:4180'),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/demo/sessions')) {
          return envelope(<String, dynamic>{
            'sessionId': 'sess-1',
            'mode': 'SIMULATED_CLASSROOM',
          });
        }
        return envelope(<String, dynamic>{
          'nearby': true,
          'captured': false,
          'count': 0,
          'totalSpecies': 3,
        });
      }),
    );

    await api.connect();
    final state = await api.state();

    expect(state.nearby, isTrue);
    final stateRequest = requests.last;
    final header = stateRequest.headers['X-Demo-Session'] ??
        stateRequest.headers['x-demo-session'];
    expect(header, 'sess-1');
    expect(stateRequest.headers.containsKey('Authorization'), isFalse);
    api.close();
  });

  test('旧题目字段映射为统一视图', () async {
    final api = DemoApi(
      baseUrl: Uri.parse('http://127.0.0.1:4180'),
      httpClient: MockClient((request) async => envelope(<String, dynamic>{
        'challengeId': 'dc1',
        'spawnId': 'library-001',
        'name': '攻城狮',
        'question': '执行 print("hello world") 之后，控制台会输出什么？',
        'options': <Object>[
          {'id': 'A', 'text': 'hello world'},
          {'id': 'B', 'text': '程序报错'},
        ],
        'source': '演示题',
      })),
    );

    final legacy = await api.challenge('library-001');
    final view = legacy.toChallengeView();

    expect(view.speciesName, '攻城狮');
    expect(view.questionText, contains('hello world'));
    expect(view.options.first.optionId, 'A');
    expect(view.sourceType, 'DEMO');
    expect(view.isSimulated, isTrue);
    api.close();
  });

  test('旧作答虽然 success，也没有正式收录号', () async {
    final api = DemoApi(
      baseUrl: Uri.parse('http://127.0.0.1:4180'),
      httpClient: MockClient((request) async => envelope(<String, dynamic>{
        'success': true,
        'message': '攻城狮已收入图鉴',
        'count': 1,
      })),
    );

    final legacy = await api.answer('dc1', 'A');
    final result = legacy.toCaptureResult('dc1');

    expect(legacy.success, isTrue);
    expect(result.captureRecordId, isNull);
    expect(result.captured, isFalse);
    api.close();
  });
}
