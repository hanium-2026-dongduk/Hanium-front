import 'dart:math';

/// 동화 생성 마법사(1~3단계)가 화면 사이에서 들고 다니는 입력값.
///
/// 화면은 `Navigator.push`로 다음 단계에 이 객체를 그대로 넘기고, 각 단계는
/// 자신이 입력받은 값만 채운다. 실제 API 호출(캐릭터 생성 → 동화 생성)은
/// 마지막 단계(`StoryResultScreen`)에서 한다.
class StoryCreatePayload {
  ({
    int childProfileId,
    int characterId,
    String background,
    String mainEvent,
    int childAge,
  })?
  _generationInput;
  String? _generationRequestId;

  /// 같은 입력으로 화면에서 다시 시도하면 서버의 같은 작업을 조회한다.
  /// 사용자가 뒤로 가서 입력을 바꾸면 새 키로 새 동화를 만든다.
  String generationRequestIdFor({
    required int childProfileId,
    required int characterId,
    required String background,
    required String mainEvent,
    int? childAge,
  }) {
    final input = (
      childProfileId: childProfileId,
      characterId: characterId,
      background: background,
      mainEvent: mainEvent,
      childAge: childAge ?? 6,
    );
    if (_generationInput != input || _generationRequestId == null) {
      _generationInput = input;
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 0x0f) | 0x40;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
      final hex = bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      _generationRequestId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    }
    return _generationRequestId!;
  }

  /// 서버가 작업을 failed로 확정한 뒤에는 같은 키를 다시 보내도 실패 상태만 돌아온다.
  void resetGenerationRequest() {
    _generationRequestId = null;
  }

  // 1단계: 캐릭터
  String? characterMethod;

  /// 동화 생성에 실제로 쓸 캐릭터 id. 방식(기존 선택/직접 그리기/랜덤)과
  /// 무관하게 `StoryCreationScreen`이 1단계를 마칠 때 채워 넣는다 — 새로 만드는
  /// 경우도 그 자리에서 캐릭터를 먼저 만들어 id를 받아온다.
  int? characterId;
  String? characterName;
  String? characterPersonality;
  String? characterDescription;

  /// 그림체. 카카오톡으로 백엔드와 이미 협의되어 필드가 추가될 예정이라
  /// UI는 유지하되 값은 아직 서버에 보내지 않는다(back#40 참고).
  String? imageStyle;

  // 2단계: 배경/사건. 백엔드가 프리셋 id 대신 자유 텍스트도 받아서
  // 앱이 원래 쓰던 한글 라벨을 그대로 `background`/`mainEvent`로 보낸다.
  String? location;
  String? event;

  /// 상세 키워드. 그림체와 마찬가지로 백엔드 필드가 아직 없어 서버에는 보내지
  /// 않고, 준비되면 이어서 반영한다.
  String? keyword;

  StoryCreatePayload({
    this.characterMethod,
    this.characterId,
    this.characterName,
    this.characterPersonality,
    this.characterDescription,
    this.imageStyle,
    this.location,
    this.event,
    this.keyword,
  });
}
