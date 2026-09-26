import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/received_sticker.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/received_sticker_provider.dart';
import 'package:hanium_front/screens/mypage/received_stickers_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/sticker_service.dart';
import 'package:provider/provider.dart';

class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 페이지마다 10개씩, 총 [total]개를 내려주는 가짜 서비스.
class _FakeStickerService implements StickerService {
  _FakeStickerService({this.total = 0});

  static const int perPage = 10;

  final int total;
  ApiException? error;
  Completer<void>? gate;
  final List<int> requestedPages = [];

  @override
  Future<PageResult<ReceivedSticker>> fetchReceived(
    int childProfileId, {
    int page = 1,
    int limit = 20,
  }) async {
    requestedPages.add(page);
    if (gate != null) await gate!.future;
    if (error != null) throw error!;

    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, total);
    return PageResult(
      items: [
        for (var i = start; i < end; i++)
          ReceivedSticker(
            stickerSendId: i + 1,
            stickerCode: 'star',
            name: '스티커 ${i + 1}',
            iconKey: 'star',
            message: i == 0 ? '오늘도 잘했어!' : null,
            sentAt: DateTime(2026, 9, 1),
          ),
      ],
      page: page,
      limit: perPage,
      totalCount: total,
      totalPages: total == 0 ? 1 : (total / perPage).ceil(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeStickerService service, {
  bool withChild = true,
  bool settle = true,
}) async {
  final activeChild = ActiveChildProvider(profileService: const _StubProfileService());
  if (withChild) {
    activeChild.setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
        ChangeNotifierProvider<ReceivedStickerProvider>(
          create: (_) => ReceivedStickerProvider(stickerService: service),
        ),
      ],
      child: const MaterialApp(home: ReceivedStickersScreen()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('스티커 이름·메시지·받은 날짜를 보여준다', (tester) async {
    await _pumpScreen(tester, _FakeStickerService(total: 2));

    expect(find.text('스티커 1'), findsOneWidget);
    expect(find.text('오늘도 잘했어!'), findsOneWidget);
    expect(find.text('2026.09.01'), findsNWidgets(2));
    expect(find.text('스티커 2'), findsOneWidget);
  });

  testWidgets('받은 스티커가 없으면 빈 안내를 보여준다', (tester) async {
    await _pumpScreen(tester, _FakeStickerService());

    expect(find.text('아직 받은 칭찬 스티커가 없어요'), findsOneWidget);
  });

  testWidgets('불러오는 동안 로딩 표시를 보여준다', (tester) async {
    final service = _FakeStickerService(total: 1)..gate = Completer<void>();
    await _pumpScreen(tester, service, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('스티커 1'), findsOneWidget);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final service = _FakeStickerService(total: 1)
      ..error = const ApiException(message: '서버에 연결할 수 없어요.');
    await _pumpScreen(tester, service);

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);

    service.error = null;
    await tester.tap(find.widgetWithText(ElevatedButton, '다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('스티커 1'), findsOneWidget);
  });

  testWidgets('끝까지 스크롤하면 다음 페이지를 이어서 불러온다', (tester) async {
    final service = _FakeStickerService(total: 15);
    await _pumpScreen(tester, service);

    expect(service.requestedPages, [1]);
    expect(find.text('스티커 11'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1, 2]);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('스티커 15'), findsOneWidget);
  });

  testWidgets('마지막 페이지에서는 더 불러오지 않는다', (tester) async {
    final service = _FakeStickerService(total: 10);
    await _pumpScreen(tester, service);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1]);
  });

  testWidgets('당겨서 새로고침하면 첫 페이지를 다시 불러온다', (tester) async {
    final service = _FakeStickerService(total: 2);
    await _pumpScreen(tester, service);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1, 1]);
  });

  testWidgets('자녀가 선택되지 않았으면 안내 문구를 보여준다', (tester) async {
    final service = _FakeStickerService(total: 2);
    await _pumpScreen(tester, service, withChild: false);

    expect(find.text('먼저 자녀 프로필을 선택해 주세요.'), findsOneWidget);
    expect(service.requestedPages, isEmpty);
  });
}
