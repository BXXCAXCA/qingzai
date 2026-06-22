import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qingzai/app/qing_zai_app.dart';

void main() {
  testWidgets('Qing Zai app renders dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QingZaiApp()));

    expect(find.text('轻载'), findsWidgets);
    expect(find.text('欢迎使用轻载'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard), findsWidgets);
  });
}
