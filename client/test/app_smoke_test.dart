import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/main.dart';

void main() {
  testWidgets('App 启动后停在登录页（不联网、不伪造登录）', (tester) async {
    await tester.pumpWidget(const PkmonApp());
    await tester.pumpAndSettle();

    expect(find.text('登录 PKMon'), findsOneWidget);
    expect(find.text('账号接口未接入（骨架）。真实登录/注册暂不可用；本页不会伪造登录成功。'),
        findsOneWidget);
  });
}
