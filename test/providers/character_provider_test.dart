import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/core/api_exception.dart';
import 'package:hanium_front/models/character.dart';
import 'package:hanium_front/providers/character_provider.dart';

import '../support/fake_character_service.dart';

void main() {
  late FakeCharacterService service;
  late CharacterProvider provider;

  setUp(() {
    service = FakeCharacterService();
    provider = CharacterProvider(characterService: service);
  });

  tearDown(() => provider.dispose());

  test('만들자마자 로딩 상태이고, load가 끝나면 목록이 채워진다', () async {
    expect(provider.isLoading, isTrue);

    await provider.load();

    expect(provider.isLoading, isFalse);
    expect(provider.loadError, isNull);
    expect(provider.characters, hasLength(1));
    expect(provider.characters.single.name, '토끼');
    expect(service.fetchCalls, 1);
  });

  test('목록이 비어 있으면 isEmpty가 true다', () async {
    service.characters = const [];

    await provider.load();

    expect(provider.isEmpty, isTrue);
  });

  test('조회가 실패하면 오류 메시지를 남긴다', () async {
    service.fetchError = const ApiException(message: '서버에 연결할 수 없어요.');

    await provider.load();

    expect(provider.loadError, '서버에 연결할 수 없어요.');
    expect(provider.characters, isEmpty);
  });

  test('create는 새 캐릭터를 목록 맨 앞에 더한다', () async {
    await provider.load();

    final created = await provider.create(
      name: '뽀로로',
      personality: '용감해요',
      description: '설명',
      type: CharacterType.random,
    );

    expect(created, isNotNull);
    expect(provider.characters.first.name, '뽀로로');
    expect(provider.characters, hasLength(2));
    expect(provider.isCreating, isFalse);
    expect(service.createCalls, 1);
  });

  test('create가 실패하면 null을 돌려주고 목록은 그대로다', () async {
    await provider.load();
    service.createError = const ApiException(
      message: '캐릭터 이름은 필수입니다.',
      statusCode: 400,
    );

    final created = await provider.create(
      name: '',
      personality: '',
      description: '',
      type: CharacterType.random,
    );

    expect(created, isNull);
    expect(provider.createError, '캐릭터 이름은 필수입니다.');
    expect(provider.characters, hasLength(1));
  });
}
