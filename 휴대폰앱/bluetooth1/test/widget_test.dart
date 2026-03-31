import 'package:flutter_test/flutter_test.dart';

import 'package:bluetooth1/main.dart'; // 실제 MyApp이 정의된 위치

void main() {
  testWidgets('MyApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 기본 테스트: 앱이 정상적으로 렌더링되는지 확인
    expect(find.text('Connect'), findsOneWidget);
  });
}
