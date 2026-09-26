import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/widgets/reward_celebration.dart';

/// 보상 축하 연출(RW05)이 획득 내용을 보여주고 스스로 닫히는지 본다.
void main() {
  Future<void> openCelebration(
    WidgetTester tester, {
    int points = 0,
    int badgeCount = 0,
    int? newLevel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showRewardCelebration(
                  context,
                  points: points,
                  badgeCount: badgeCount,
                  newLevel: newLevel,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  testWidgets('획득 포인트와 새 배지, 레벨업을 보여준다', (tester) async {
    await openCelebration(tester, points: 30, badgeCount: 2, newLevel: 4);

    expect(find.text('+30'), findsOneWidget);
    expect(find.text('마법 토큰 30개를 받았어요!'), findsOneWidget);
    expect(find.text('🏅 새 배지 2개를 얻었어요!'), findsOneWidget);
    expect(find.text('레벨 업! Lv.4'), findsOneWidget);

    // 자동으로 닫히는 타이머를 지나 보내서 테스트가 끝나기 전에 정리한다.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('포인트만 얻었으면 배지·레벨 문구는 보이지 않는다', (tester) async {
    await openCelebration(tester, points: 10);

    expect(find.text('+10'), findsOneWidget);
    expect(find.textContaining('새 배지'), findsNothing);
    expect(find.textContaining('레벨 업'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('일정 시간이 지나면 저절로 닫힌다', (tester) async {
    await openCelebration(tester, points: 10);
    expect(find.byType(RewardCelebration), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(RewardCelebration), findsNothing);
  });

  testWidgets('화면을 누르면 바로 닫힌다', (tester) async {
    await openCelebration(tester, points: 10);

    await tester.tap(find.byType(RewardCelebration));
    await tester.pumpAndSettle();

    expect(find.byType(RewardCelebration), findsNothing);
  });
}
