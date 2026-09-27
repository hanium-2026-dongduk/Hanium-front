import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/story_payload.dart';
import 'package:hanium_front/screens/story_keyword_screen.dart';
import 'package:hanium_front/screens/story_setting_screen.dart';

/// 동화 배경/사건 선택(STEP1) — 프리셋·직접 입력·유효성 검사를 본다.
void main() {
  Future<StoryCreatePayload> pumpScreen(WidgetTester tester) async {
    // 직접 입력 필드가 펼쳐져도 스크롤 없이 버튼까지 보이도록 넉넉히 그린다.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final payload = StoryCreatePayload();
    await tester.pumpWidget(
      MaterialApp(home: StorySettingScreen(payload: payload)),
    );
    return payload;
  }

  testWidgets('배경·사건을 모두 고르지 않으면 안내만 뜨고 이동하지 않는다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('다음'));
    await tester.pump();

    expect(find.text('배경과 사건을 하나씩 골라 주세요!'), findsOneWidget);
    expect(find.byType(StoryKeywordScreen), findsNothing);
  });

  testWidgets('프리셋을 하나씩 고르면 payload에 그대로 담겨 다음 화면으로 넘어간다', (tester) async {
    final payload = await pumpScreen(tester);

    await tester.tap(find.text('신비로운 숲'));
    await tester.tap(find.text('친구 구하기'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.byType(StoryKeywordScreen), findsOneWidget);
    expect(payload.location, '신비로운 숲');
    expect(payload.event, '친구 구하기');
  });

  testWidgets('직접 입력을 고르면 입력창이 나타나고 입력한 값이 payload에 담긴다', (tester) async {
    final payload = await pumpScreen(tester);

    // 배경·사건 두 줄에 모두 '직접 입력'이 있어 순서대로(위: 배경, 아래: 사건) 짚는다.
    final customButtons = find.text('직접 입력');
    expect(customButtons, findsNWidgets(2));

    await tester.tap(customButtons.at(0));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '별들이 춤추는 밤하늘');

    await tester.tap(customButtons.at(1));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '잃어버린 목소리를 되찾는다');
    await tester.pump();

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.byType(StoryKeywordScreen), findsOneWidget);
    expect(payload.location, '별들이 춤추는 밤하늘');
    expect(payload.event, '잃어버린 목소리를 되찾는다');
  });

  testWidgets('직접 입력을 비워두면 안내만 뜨고 이동하지 않는다', (tester) async {
    await pumpScreen(tester);

    final customButtons = find.text('직접 입력');
    await tester.tap(customButtons.at(0));
    await tester.tap(customButtons.at(1));
    await tester.pump();

    await tester.tap(find.text('다음'));
    await tester.pump();

    expect(find.text('배경과 사건을 하나씩 골라 주세요!'), findsOneWidget);
    expect(find.byType(StoryKeywordScreen), findsNothing);
  });
}
