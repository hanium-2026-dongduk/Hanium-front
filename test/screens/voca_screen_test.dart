import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/child_profile.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/vocabulary_entry.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/screens/voca_screen.dart';
import 'package:hanium_front/services/profile_service.dart';
import 'package:hanium_front/services/tts_service.dart';
import 'package:hanium_front/services/vocabulary_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_flutter_tts.dart';

/// 단어장 화면(VB01~VB04)이 목록·발음·삭제·즐겨찾기를 제대로 다루는지 본다.
/// 통신은 하지 않고 VocabularyService 대신 가짜를 끼운다.
class _StubProfileService implements ProfileService {
  const _StubProfileService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVocabularyService implements VocabularyService {
  _FakeVocabularyService(this._entries);

  List<VocabularyEntry> _entries;
  ApiException? fetchError;
  final List<int> deletedIds = [];

  @override
  Future<PageResult<VocabularyEntry>> fetchEntries(int childProfileId, {int page = 1, int limit = 20}) async {
    if (fetchError != null) throw fetchError!;
    return PageResult(items: _entries, page: 1, limit: limit, totalCount: _entries.length, totalPages: 1);
  }

  @override
  Future<void> deleteEntry(int vocabularyEntryId, int childProfileId) async {
    deletedIds.add(vocabularyEntryId);
    _entries = _entries.where((e) => e.vocabularyEntryId != vocabularyEntryId).toList();
  }

  @override
  Future<VocabularyEntry> saveEntry({
    required int childProfileId,
    int? storyId,
    required String englishWord,
    required String koreanMeaning,
    String? exampleSentence,
  }) => throw UnimplementedError();
}

VocabularyEntry _entry({
  required int id,
  required String en,
  required String ko,
  String? example,
}) {
  return VocabularyEntry(
    vocabularyEntryId: id,
    childProfileId: 1,
    englishWord: en,
    koreanMeaning: ko,
    exampleSentence: example,
    createdAt: DateTime(2026, 8, 12),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester, _FakeVocabularyService service) async {
    final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
      ..setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          Provider<VocabularyService>.value(value: service),
          Provider<TtsService>(create: (_) => TtsService(flutterTts: FakeFlutterTts())),
        ],
        child: const MaterialApp(home: VocaScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('단어가 없으면 안내 문구를 보여준다', (tester) async {
    await pumpScreen(tester, _FakeVocabularyService([]));

    expect(find.textContaining('아직 저장된 단어가 없어요'), findsOneWidget);
  });

  testWidgets('영단어·뜻·예문을 함께 보여준다', (tester) async {
    await pumpScreen(
      tester,
      _FakeVocabularyService([
        _entry(id: 1, en: 'Castle', ko: '성, 대저택', example: 'The castle is big.'),
      ]),
    );

    expect(find.text('Castle'), findsOneWidget);
    expect(find.text('성, 대저택'), findsOneWidget);
    expect(find.text('The castle is big.'), findsOneWidget);
  });

  testWidgets('목록을 못 불러오면 오류와 다시 시도 버튼을 보여준다', (tester) async {
    final service = _FakeVocabularyService([])..fetchError = const ApiException(message: '서버에 연결할 수 없어요.');
    await pumpScreen(tester, service);

    expect(find.text('서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('발음 듣기 버튼을 누르면 TTS가 해당 단어를 읽는다', (tester) async {
    final fakeTts = FakeFlutterTts();
    final activeChild = ActiveChildProvider(profileService: const _StubProfileService())
      ..setActiveChild(const ChildProfile(childProfileId: 1, childName: '첫째'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ActiveChildProvider>.value(value: activeChild),
          Provider<VocabularyService>.value(
            value: _FakeVocabularyService([_entry(id: 1, en: 'Magic', ko: '마법')]),
          ),
          Provider<TtsService>(create: (_) => TtsService(flutterTts: fakeTts)),
        ],
        child: const MaterialApp(home: VocaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('발음 듣기'));
    await tester.pumpAndSettle();

    expect(fakeTts.spokenWords, ['Magic']);
  });

  testWidgets('즐겨찾기 별을 누르면 즐겨찾기만 보기 필터에 반영된다', (tester) async {
    await pumpScreen(
      tester,
      _FakeVocabularyService([
        _entry(id: 1, en: 'Castle', ko: '성'),
        _entry(id: 2, en: 'Magic', ko: '마법'),
      ]),
    );

    // 처음엔 즐겨찾기가 없어 둘 다 보인다.
    expect(find.text('Castle'), findsOneWidget);
    expect(find.text('Magic'), findsOneWidget);

    await tester.tap(find.byTooltip('즐겨찾기').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('즐겨찾기만'));
    await tester.pumpAndSettle();

    expect(find.text('Castle'), findsOneWidget);
    expect(find.text('Magic'), findsNothing);
  });

  testWidgets('삭제는 확인을 받고 나서 실행한다', (tester) async {
    final service = _FakeVocabularyService([_entry(id: 1, en: 'Castle', ko: '성')]);
    await pumpScreen(tester, service);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"Castle" 단어를 단어장에서 지울까요?'), findsOneWidget);

    // 취소하면 아무 일도 없어야 한다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(service.deletedIds, isEmpty);
    expect(find.text('Castle'), findsOneWidget);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(service.deletedIds, [1]);
    expect(find.text('Castle'), findsNothing);
  });
}
