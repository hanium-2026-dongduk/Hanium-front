import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/story_payload.dart';
import 'package:hanium_front/providers/story_result_provider.dart';
import 'package:hanium_front/services/story_service.dart';

import '../support/fake_story_service.dart';

void main() {
  late FakeStoryService service;

  setUp(() {
    service = FakeStoryService();
  });

  group('생성 모드 (payload)', () {
    test('캐릭터·배경·사건으로 동화를 만들고 storyId를 채운다', () async {
      final payload = StoryCreatePayload(
        characterId: 9,
        location: '신비로운 숲',
        event: '숨겨진 보물 찾기',
      );
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        payload: payload,
        childAge: 7,
      );

      expect(provider.isLoading, isTrue);
      await provider.load();

      expect(provider.isLoading, isFalse);
      expect(provider.loadError, isNull);
      expect(provider.storyId, 42);
      expect(provider.story?.title, 'The Rabbit Adventure');
      expect(provider.choices, ['간다', '멈춘다']);
      expect(service.lastRequestId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      // 서버 프롬프트 난이도에 쓰이므로 자녀 나이가 함께 전달돼야 한다.
      expect(service.lastCreateArgs, {
        'childProfileId': 3,
        'characterId': 9,
        'background': '신비로운 숲',
        'mainEvent': '숨겨진 보물 찾기',
        'childAge': 7,
      });

      provider.dispose();
    });

    test('캐릭터 id가 없으면 API를 부르지 않고 안내 메시지를 남긴다', () async {
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        payload: StoryCreatePayload(location: '숲', event: '보물 찾기'),
      );

      await provider.load();

      expect(provider.loadError, isNotNull);
      expect(service.createCalls, 0);

      provider.dispose();
    });

    test('생성이 실패하면 오류 메시지를 남긴다', () async {
      service.createError = const ApiException(
        message: '이미지 생성 실패',
        statusCode: 500,
      );
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        payload: StoryCreatePayload(
          characterId: 9,
          location: '숲',
          event: '보물 찾기',
        ),
      );

      await provider.load();

      expect(provider.loadError, '이미지 생성 실패');
      expect(provider.storyId, isNull);

      provider.dispose();
    });

    test('일시적인 오류 후 다시 시도해도 같은 생성 요청 키를 쓴다', () async {
      service.createError = const ApiException(message: '네트워크 오류');
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        payload: StoryCreatePayload(characterId: 9, location: '숲', event: '탐험'),
      );

      await provider.load();
      service.createError = null;
      await provider.load();

      expect(service.requestIds, hasLength(2));
      expect(service.requestIds[1], service.requestIds[0]);
      expect(provider.storyId, 42);
      provider.dispose();
    });

    test('확정 실패 후 다시 시도할 때는 새 생성 요청 키를 쓴다', () async {
      service.createError = const StoryGenerationFailedException('생성 실패');
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        payload: StoryCreatePayload(characterId: 9, location: '숲', event: '탐험'),
      );

      await provider.load();
      service.createError = null;
      await provider.load();

      expect(service.requestIds, hasLength(2));
      expect(service.requestIds[1], isNot(service.requestIds[0]));
      provider.dispose();
    });
  });

  group('조회 모드 (storyId)', () {
    test('이미 저장된 동화를 불러오고 choices는 비어 있다', () async {
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        initialStoryId: 42,
        initialIsFavorite: true,
      );

      await provider.load();

      expect(provider.storyId, 42);
      expect(provider.isFavorite, isTrue);
      expect(service.fetchStoryCalls, 1);
      expect(service.createCalls, 0);

      provider.dispose();
    });
  });

  group('즐겨찾기', () {
    test('꺼진 상태에서 toggle하면 addFavorite을 부르고 true가 된다', () async {
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        initialStoryId: 42,
      );
      await provider.load();

      await provider.toggleFavorite();

      expect(provider.isFavorite, isTrue);
      expect(service.addFavoriteCalls, 1);
      expect(service.removeFavoriteCalls, 0);

      provider.dispose();
    });

    test('실패하면 상태를 되돌리지 않고 오류 메시지를 남긴다', () async {
      final provider = StoryResultProvider(
        storyService: service,
        childProfileId: 3,
        initialStoryId: 42,
      );
      await provider.load();
      service.favoriteError = const ApiException(message: '서버에 연결할 수 없어요.');

      await provider.toggleFavorite();

      expect(provider.isFavorite, isFalse);
      expect(provider.favoriteError, '서버에 연결할 수 없어요.');

      provider.dispose();
    });
  });
}
