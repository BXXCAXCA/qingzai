import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qingzai/app/qing_zai_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app shell renders dashboard and primary navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QingZaiApp()));
    await tester.pumpAndSettle();

    expect(find.text('轻载'), findsOneWidget);
    expect(find.text('欢迎使用轻载'), findsOneWidget);
    expect(find.text('待办'), findsOneWidget);
    expect(find.text('剪切板'), findsOneWidget);
    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('番茄钟'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
