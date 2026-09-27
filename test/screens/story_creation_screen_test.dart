import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/character.dart';
import 'package:hanium_front/screens/story_creation_screen.dart';
import 'package:hanium_front/screens/story_setting_screen.dart';
import 'package:hanium_front/services/character_service.dart';
import 'package:provider/provider.dart';

import '../support/fake_character_service.dart';

/// 동화 생성 1단계(SG01·SG02) — 캐릭터 준비 방식별 분기를 본다.
Future<FakeCharacterService> _pumpScreen(WidgetTester tester) async {
  // 화면 전체(스크롤 없이 버튼까지)가 들어오도록 넉넉한 화면으로 그린다.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final service = FakeCharacterService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<CharacterService>.value(value: service)],
      child: const MaterialApp(home: StoryCreationScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('기본값은 기존 캐릭터 선택이고 목록에서 고르면 다음 단계로 넘어간다', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('토끼'), findsOneWidget);
    await tester.tap(find.text('토끼'));
    await tester.pump();
    await tester.tap(find.text('다음 단계로 (스토리 배경 설정)'));
    await tester.pumpAndSettle();

    expect(find.byType(StorySettingScreen), findsOneWidget);
  });

  testWidgets('기존 캐릭터를 고르지 않고 다음을 누르면 안내만 뜨고 이동하지 않는다', (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('다음 단계로 (스토리 배경 설정)'));
    await tester.pump();

    expect(find.text('캐릭터를 선택해 주세요!'), findsOneWidget);
    expect(find.byType(StorySettingScreen), findsNothing);
  });

  testWidgets('랜덤 생성을 고르면 이름이 자동으로 채워지고, 다음을 누르면 캐릭터를 만들어 이동한다', (
    tester,
  ) async {
    final service = await _pumpScreen(tester);

    await tester.tap(find.text('랜덤 생성'));
    await tester.pump();
    await tester.tap(find.text('다음 단계로 (스토리 배경 설정)'));
    await tester.pumpAndSettle();

    expect(find.byType(StorySettingScreen), findsOneWidget);
    expect(service.createCalls, 1);
    expect(service.lastCreated?.type, CharacterType.random);
  });

  testWidgets('직접 그리기에서 이름을 비워두면 안내만 뜨고 캐릭터를 만들지 않는다', (tester) async {
    final service = await _pumpScreen(tester);

    await tester.tap(find.text('직접 그리기'));
    await tester.pump();
    await tester.tap(find.text('다음 단계로 (스토리 배경 설정)'));
    await tester.pump();

    expect(find.text('캐릭터 이름을 입력해 주세요!'), findsOneWidget);
    expect(service.createCalls, 0);
  });
}
