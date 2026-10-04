import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hanium_front/screens/parent_screen.dart';
import 'package:hanium_front/providers/parent_dashboard_provider.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/dashboard_summary.dart';

// -----------------------------------------------------------------------------
// 1. 가짜(Fake) 모델 및 Provider 생성
// -----------------------------------------------------------------------------

/// 화면에 뿌려질 가짜 자녀 프로필
class FakeChildProfile implements ChildProfile {
  @override final int childProfileId = 1;
  @override final String childName = '김우진';
  @override final int age = 6;
  @override final String? profileImageUrl = null;

  @override final LearningLevel learningLevel = LearningLevel.beginner;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 4대 상태를 자유자재로 조작할 가짜 대시보드 Provider
class FakeParentDashboardProvider extends ChangeNotifier implements ParentDashboardProvider {
  bool _testIsLoading = false;
  String? _testErrorMessage;
  List<ChildProfile> _testChildren = [];

  @override bool get isLoading => _testIsLoading;
  @override String? get errorMessage => _testErrorMessage;
  @override List<ChildProfile> get children => _testChildren;
  @override ChildProfile? get selectedChild => _testChildren.isNotEmpty ? _testChildren.first : null;

  @override Map<String, dynamic>? get usageData => null;
  @override DashboardSummary? get dashboardSummary => null;
  @override List<dynamic> get stickers => [];

  @override
  Future<void> loadInitialData() async {}

  // 테스트용 상태 조작 함수
  void setStatus({bool loading = false, String? error, bool hasChild = false}) {
    _testIsLoading = loading;
    _testErrorMessage = error;
    _testChildren = hasChild ? [FakeChildProfile()] : [];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// -----------------------------------------------------------------------------
// 2. 4대 상태 위젯 테스트
// -----------------------------------------------------------------------------

void main() {
  late FakeParentDashboardProvider fakeProvider;

  setUp(() {
    fakeProvider = FakeParentDashboardProvider();
  });

  Widget createTestWidget() {
    return ChangeNotifierProvider<ParentDashboardProvider>.value(
      value: fakeProvider,
      child: const MaterialApp(
        home: ParentScreen(),
      ),
    );
  }

  group('ParentScreen 4대 상태 위젯 테스트', () {
    testWidgets('1. Loading 상태: 로딩 스피너가 표시된다', (WidgetTester tester) async {
      // 자녀 데이터가 없고 로딩 중인 상태
      fakeProvider.setStatus(loading: true, hasChild: false);

      await tester.pumpWidget(createTestWidget());

      // CircularProgressIndicator가 화면에 있는지 확인
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. Error 상태: 에러 메시지와 다시 시도 버튼이 표시된다', (WidgetTester tester) async {
      fakeProvider.setStatus(loading: false, error: '서버 에러가 발생했습니다.', hasChild: false);

      await tester.pumpWidget(createTestWidget());

      // 에러 메시지와 다시 시도 버튼 확인
      expect(find.text('서버 에러가 발생했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('3. Empty 상태: 자녀 데이터가 없으면 안내 문구가 표시된다', (WidgetTester tester) async {
      fakeProvider.setStatus(loading: false, error: null, hasChild: false);

      await tester.pumpWidget(createTestWidget());

      // 빈 화면 안내 문구 확인
      expect(find.text('등록된 자녀 프로필이 없습니다.'), findsOneWidget);
    });

    testWidgets('4. Success 상태: 자녀 정보와 대시보드 UI가 정상 렌더링된다', (WidgetTester tester) async {
      fakeProvider.setStatus(loading: false, error: null, hasChild: true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(); // 애니메이션 완료 대기

      // FakeChildProfile에 넣은 이름('김우진')이 화면에 잘 떴는지 확인
      expect(find.text('김우진'), findsOneWidget);

      // 핵심 UI 카드들이 렌더링되었는지 확인
      expect(find.text('자녀 프로필 정보'), findsOneWidget);
      expect(find.text('칭찬 스티커 발송'), findsOneWidget);
    });
  });
}
