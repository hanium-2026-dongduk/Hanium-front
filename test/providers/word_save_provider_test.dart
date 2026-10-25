import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/providers/word_save_provider.dart';

import '../support/fake_vocabulary_service.dart';

/// 단어 뜻 보기·저장 Provider가 같은 단어를 두 번 저장하지 않는지 본다.
void main() {
  WordSaveProvider build(FakeVocabularyService service) =>
      WordSaveProvider(vocabularyService: service, childProfileId: 3);

  test('비교용 키는 앞뒤 문장부호·대소문자·둥근 따옴표를 무시한다', () {
    expect(WordSaveProvider.normalize('"Apple,"'), 'apple');
    expect(WordSaveProvider.normalize(' Don’t! '), "don't");
    expect(WordSaveProvider.normalize('—'), '');
  });

  test('뜻은 한 번만 조회하고 결과를 기억한다', () async {
    final service = FakeVocabularyService();
    final provider = build(service);

    await Future.wait([provider.lookup('once'), provider.lookup('once')]);
    await provider.lookup('once');

    expect(service.lookupCalls, ['once']);
    expect(provider.meaningOf('once')?.koreanMeaning, '한 번, 옛날에');
  });

  test('뜻을 모르는 단어(404)와 그 외 실패는 다른 문구로 알려준다', () async {
    final service = FakeVocabularyService();
    final provider = build(service);

    await provider.lookup('zzzz');
    expect(provider.lookupErrorOf('zzzz'), '이 단어의 뜻은 아직 몰라요.');

    service.lookupError = const ApiException(message: '오류', statusCode: 502);
    await provider.lookup('once');
    expect(provider.lookupErrorOf('once'), '뜻을 불러오지 못했어요. 다시 눌러 볼까요?');
  });

  test('저장 요청 중에 다시 눌러도 한 번만 보낸다', () async {
    final service = FakeVocabularyService()..saveGate = Completer<void>();
    final provider = build(service);
    await provider.lookup('once');

    final first = provider.save('once', storyId: 7);
    await pumpEventQueue();
    expect(provider.isSaving('once'), isTrue);
    await provider.save('once', storyId: 7);

    service.saveGate!.complete();
    expect(await first, isNull);
    expect(service.saveCalls, hasLength(1));
    expect(service.saveCalls.single.storyId, 7);
    expect(provider.isSaved('once'), isTrue);

    await provider.save('once', storyId: 7);
    expect(service.saveCalls, hasLength(1));
  });

  test('단어장에 이미 있는 단어는 대소문자가 달라도 저장하지 않는다', () async {
    final service = FakeVocabularyService(savedWords: ['Once']);
    final provider = build(service);
    await provider.loadSavedWords();
    await provider.lookup('once');

    expect(provider.isSaved('once'), isTrue);
    expect(await provider.save('once'), isNull);
    expect(service.saveCalls, isEmpty);
  });

  test('단어장 목록을 받기 전에 저장해도 목록을 먼저 확인한다', () async {
    final service = FakeVocabularyService(savedWords: ['once']);
    final provider = build(service);
    await provider.lookup('once');

    await provider.save('once');

    expect(service.saveCalls, isEmpty);
    expect(provider.isSaved('once'), isTrue);
  });

  test('단어장 목록을 못 받아도 저장할 수 있고, 다음에 다시 받는다', () async {
    final service = FakeVocabularyService()
      ..fetchError = const ApiException(message: '오류');
    final provider = build(service);
    await provider.loadSavedWords();
    await provider.lookup('once');
    service.fetchError = null;

    expect(await provider.save('once'), isNull);

    expect(service.fetchCalls, 2);
    expect(service.saveCalls, hasLength(1));
  });

  test('저장에 실패하면 문구를 돌려주고 다시 저장할 수 있다', () async {
    final service = FakeVocabularyService()
      ..saveError = const ApiException(message: '오류', statusCode: 500);
    final provider = build(service);
    await provider.lookup('once');

    expect(await provider.save('once'), '단어를 저장하지 못했어요. 잠시 후 다시 해 볼까요?');
    expect(provider.isSaved('once'), isFalse);
    expect(provider.isSaving('once'), isFalse);

    service.saveError = null;
    expect(await provider.save('once'), isNull);
    expect(provider.isSaved('once'), isTrue);
  });

  test('뜻을 받기 전에는 저장하지 않는다', () async {
    final service = FakeVocabularyService();
    final provider = build(service);

    await provider.save('once');

    expect(service.saveCalls, isEmpty);
  });
}
