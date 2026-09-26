import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/providers/quiz_provider.dart';

import '../support/fake_quiz_service.dart';

void main() {
  late FakeQuizService service;
  late QuizProvider provider;

  setUp(() {
    service = FakeQuizService();
    provider = QuizProvider(quizService: service, childProfileId: 3, storyId: 11);
  });

  tearDown(() => provider.dispose());

  test('만들자마자 로딩 상태이고, load가 끝나면 문항이 채워진다', () async {
    expect(provider.isLoading, isTrue);

    await provider.load();

    expect(provider.isLoading, isFalse);
    expect(provider.loadError, isNull);
    expect(provider.questions, hasLength(2));
    expect(provider.currentQuestion?.questionId, 101);
    expect(service.generateCalls, 1);
    expect(service.fetchCalls, 1);
  });

  test('생성이 실패하면 오류 메시지를 남긴다', () async {
    service.generateError = const ApiException(message: '퀴즈 생성에 실패했습니다.', statusCode: 502);

    await provider.load();

    expect(provider.isLoading, isFalse);
    expect(provider.loadError, '퀴즈 생성에 실패했습니다.');
    expect(provider.questions, isEmpty);
    expect(provider.isEmpty, isFalse);
  });

  test('조회만 실패했다가 다시 시도하면 생성은 반복하지 않는다', () async {
    service.fetchError = const ApiException(message: '서버에 연결할 수 없어요.');
    await provider.load();
    expect(provider.loadError, isNotNull);

    service.fetchError = null;
    await provider.load();

    expect(provider.loadError, isNull);
    expect(provider.questions, hasLength(2));
    expect(service.generateCalls, 1);
    expect(service.fetchCalls, 2);
  });

  test('문항이 하나도 없으면 비어 있는 상태다', () async {
    service.questions = const [];

    await provider.load();

    expect(provider.isEmpty, isTrue);
    expect(provider.loadError, isNull);
  });

  test('보기를 고르고 다음·이전 문항으로 이동한다', () async {
    await provider.load();

    expect(provider.isCurrentAnswered, isFalse);
    provider.select(101, 1002);
    expect(provider.selectedOptionId(101), 1002);
    expect(provider.isCurrentAnswered, isTrue);

    provider.next();
    expect(provider.currentQuestion?.questionId, 102);
    expect(provider.isLastQuestion, isTrue);
    expect(provider.isCurrentAnswered, isFalse);

    provider.next(); // 마지막이면 더 넘어가지 않는다.
    expect(provider.currentIndex, 1);

    provider.previous();
    expect(provider.currentIndex, 0);
    expect(provider.selectedOptionId(101), 1002);
  });

  test('없는 문항이나 다른 문항의 보기는 무시한다', () async {
    await provider.load();

    provider.select(999, 1001);
    provider.select(101, 1003); // 102번 문항의 보기

    expect(provider.selectedOptionId(999), isNull);
    expect(provider.selectedOptionId(101), isNull);
  });

  test('모두 답하기 전에는 제출하지 않는다', () async {
    await provider.load();
    provider.select(101, 1001);

    expect(provider.allAnswered, isFalse);
    expect(await provider.submit(), isNull);
    expect(service.submitCalls, 0);
  });

  test('모두 답하면 제출하고 채점 결과를 보관한다', () async {
    await provider.load();
    provider.select(101, 1001);
    provider.select(102, 1004);

    final result = await provider.submit();

    expect(result, isNotNull);
    expect(provider.isSubmitted, isTrue);
    expect(provider.result?.correctCount, 1);
    expect(service.lastAnswers, {101: 1001, 102: 1004});
  });

  test('채점이 끝나면 다시 제출하거나 답을 바꿀 수 없다 (포인트 중복 지급 방지)', () async {
    await provider.load();
    provider.select(101, 1001);
    provider.select(102, 1003);
    await provider.submit();

    provider.select(101, 1002);
    final again = await provider.submit();
    await provider.load();

    expect(again, isNull);
    expect(provider.selectedOptionId(101), 1001);
    expect(service.submitCalls, 1);
    expect(service.generateCalls, 1); // 문항이 교체되지 않는다.
  });

  test('제출 중에 또 눌러도 요청은 한 번만 나간다', () async {
    await provider.load();
    provider.select(101, 1001);
    provider.select(102, 1003);
    service.submitGate = Completer<void>();

    final first = provider.submit();
    expect(provider.isSubmitting, isTrue);
    final second = await provider.submit();
    provider.select(101, 1002); // 제출 중에는 답을 바꿀 수 없다.

    service.submitGate!.complete();
    await first;

    expect(second, isNull);
    expect(service.submitCalls, 1);
    expect(service.lastAnswers, {101: 1001, 102: 1003});
    expect(provider.isSubmitting, isFalse);
  });

  test('제출이 실패하면 오류를 남기고 답안은 유지해 다시 제출할 수 있다', () async {
    await provider.load();
    provider.select(101, 1001);
    provider.select(102, 1003);
    service.submitError = const ApiException(message: '서버에 연결할 수 없어요.');

    expect(await provider.submit(), isNull);
    expect(provider.submitError, '서버에 연결할 수 없어요.');
    expect(provider.isSubmitted, isFalse);
    expect(provider.selectedOptionId(101), 1001);

    service.submitError = null;
    expect(await provider.submit(), isNotNull);
    expect(provider.submitError, isNull);
    expect(provider.isSubmitted, isTrue);
  });

  test('화면이 닫힌 뒤에 응답이 돌아와도 예외 없이 끝난다', () async {
    final disposable = QuizProvider(quizService: service, childProfileId: 3, storyId: 11);
    final loading = disposable.load();
    disposable.dispose();

    await expectLater(loading, completes);
  });
}
