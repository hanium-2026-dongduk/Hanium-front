import 'dart:async';

import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/page_result.dart';
import 'package:hanium_front/models/vocabulary_entry.dart';
import 'package:hanium_front/models/word_meaning.dart';
import 'package:hanium_front/services/vocabulary_service.dart';

/// 단어 뜻 보기·저장 테스트용 가짜 단어장 서비스. 통신하지 않는다.
class FakeVocabularyService implements VocabularyService {
  FakeVocabularyService({
    List<String> savedWords = const [],
    Map<String, String> meanings = const {'once': '한 번, 옛날에'},
  }) : savedWords = [...savedWords],
       meanings = {...meanings};

  /// 단어장에 이미 있는 영어 단어.
  final List<String> savedWords;

  /// 뜻 조회 결과. 없는 단어는 404로 응답한다.
  final Map<String, String> meanings;

  ApiException? fetchError;
  ApiException? lookupError;
  ApiException? saveError;

  /// 값을 넣으면 저장 요청이 이 Completer가 끝날 때까지 기다린다. 연타 확인용.
  Completer<void>? saveGate;

  int fetchCalls = 0;
  final List<String> lookupCalls = [];
  final List<({int? storyId, String englishWord, String koreanMeaning})>
  saveCalls = [];

  @override
  Future<PageResult<VocabularyEntry>> fetchEntries(
    int childProfileId, {
    int page = 1,
    int limit = 20,
  }) async {
    fetchCalls++;
    if (fetchError != null) throw fetchError!;
    return PageResult(
      items: [
        for (final (i, word) in savedWords.indexed)
          VocabularyEntry(
            vocabularyEntryId: i + 1,
            childProfileId: childProfileId,
            englishWord: word,
            koreanMeaning: '뜻',
            createdAt: DateTime(2026, 10, 18),
          ),
      ],
      page: page,
      limit: limit,
      totalCount: savedWords.length,
      totalPages: 1,
    );
  }

  @override
  Future<WordMeaning> lookupMeaning(String word) async {
    lookupCalls.add(word);
    if (lookupError != null) throw lookupError!;
    final meaning = meanings[word];
    if (meaning == null) {
      throw const ApiException(message: '단어 뜻을 찾을 수 없습니다.', statusCode: 404);
    }
    return WordMeaning(englishWord: word, koreanMeaning: meaning);
  }

  @override
  Future<VocabularyEntry> saveEntry({
    required int childProfileId,
    int? storyId,
    required String englishWord,
    required String koreanMeaning,
    String? exampleSentence,
  }) async {
    saveCalls.add((
      storyId: storyId,
      englishWord: englishWord,
      koreanMeaning: koreanMeaning,
    ));
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    savedWords.add(englishWord);
    return VocabularyEntry(
      vocabularyEntryId: savedWords.length,
      childProfileId: childProfileId,
      storyId: storyId,
      englishWord: englishWord,
      koreanMeaning: koreanMeaning,
      createdAt: DateTime(2026, 10, 18),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
