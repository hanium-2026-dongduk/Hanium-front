import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/daily_mission.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/screens/mission_screen.dart';
import 'package:hanium_front/services/mission_service.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:provider/provider.dart';

/// 오늘의 미션 화면(RW01)이 진행도/완료 상태를 보여주는지 본다.
/// "보상받기" 버튼이 없다는 것도 함께 확인한다 — 이 도메인은 서버가 자동 지급한다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMissionService implements MissionService {
  _FakeMissionService(this._missions);

  final List<DailyMission> _missions;
  ApiException? progressError;

  @override
  Future<List<DailyMission>> fetchProgress(int childProfileId) async {
    if (progressError != null) throw progressError!;
    return _missions;
  }

  @override
  Future<List<DailyMission>> fetchCatalog() => throw UnimplementedError();
}

DailyMission _mission({
  required MissionType type,
  required int target,
  required int progress,
  required int reward,
  required MissionStatus status,
}) {
  return DailyMission(
    type: type,
    targetCount: target,
    progressCount: progress,
    rewardPoints: reward,
    status: status,
  );
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, _FakeMissionService service) async {
    final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
      ..setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          Provider<MissionService>.value(value: service),
        ],
        child: const MaterialApp(home: MissionScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('진행 중인 미션은 진행도와 목표 포인트를 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeMissionService([
        _mission(type: MissionType.wordClicked, target: 5, progress: 2, reward: 15, status: MissionStatus.pending),
      ]),
    );

    expect(find.text('단어 5개 모으기'), findsOneWidget);
    expect(find.text('2 / 5  ·  +15 토큰'), findsOneWidget);
  });

  testWidgets('완료된 미션은 획득 포인트와 체크 표시를 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeMissionService([
        _mission(type: MissionType.attendance, target: 1, progress: 1, reward: 10, status: MissionStatus.rewarded),
      ]),
    );

    expect(find.text('+10 토큰 획득'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('completed 상태도 rewarded와 같이 완료로 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeMissionService([
        _mission(type: MissionType.quizAnswered, target: 1, progress: 1, reward: 20, status: MissionStatus.completed),
      ]),
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('보상받기 버튼은 어디에도 없다 — 서버가 자동으로 지급한다', (tester) async {
    await pumpScreen(
      tester,
      _FakeMissionService([
        _mission(type: MissionType.attendance, target: 1, progress: 1, reward: 10, status: MissionStatus.rewarded),
        _mission(type: MissionType.storyRead, target: 1, progress: 0, reward: 20, status: MissionStatus.pending),
      ]),
    );

    expect(find.widgetWithText(ElevatedButton, '보상받기'), findsNothing);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final service = _FakeMissionService([])..progressError = const ApiException(message: '서버에 연결할 수 없어요.');
    await pumpScreen(tester, service);

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });
}
