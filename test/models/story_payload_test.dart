import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/story_payload.dart';

void main() {
  test('같은 동화 입력은 같은 키를 쓰고 입력을 바꾸면 새 키를 쓴다', () {
    final payload = StoryCreatePayload(
      characterId: 9,
      location: '숲',
      event: '탐험',
    );
    String key({String background = '숲', int? age}) =>
        payload.generationRequestIdFor(
          childProfileId: 3,
          characterId: 9,
          background: background,
          mainEvent: '탐험',
          childAge: age,
        );

    final first = key();
    expect(key(age: 6), first);
    expect(
      first,
      matches(RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')),
    );
    final changed = key(background: '바다');
    expect(changed, isNot(first));
    payload.resetGenerationRequest();
    expect(key(background: '바다'), isNot(changed));
  });
}
