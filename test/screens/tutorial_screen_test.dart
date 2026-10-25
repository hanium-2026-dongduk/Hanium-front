import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/screens/tutorial_screen.dart';

/// 첫 실행 튜토리얼(P-TU-ST07) — 낮은 화면에서도 내용이 넘치지 않고 버튼이 눌린다.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: TutorialScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('높이가 낮은 가로 화면에서도 모든 페이지가 overflow 없이 그려진다', (tester) async {
    await pumpAt(tester, const Size(1000, 471));
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('세로 화면에서는 건너뛰기와 다음 버튼이 보이고, 마지막 페이지에서 건너뛰기가 사라진다', (
    tester,
  ) async {
    await pumpAt(tester, const Size(800, 1400));

    expect(find.text('건너뛰기'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('건너뛰기'), findsNothing);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
