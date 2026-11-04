import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/main.dart';

void main() {
  testWidgets('App 启动后停在登录页（不联网、不伪造登录）', (tester) async {
    await tester.pumpWidget(const PkmonApp());
    await tester.pumpAndSettle();

    expect(find.text('登录 PKMon'), findsOneWidget);
    expect(find.text('登录后可开始自习并保存本次会话。'),
        findsOneWidget);
  });
}
