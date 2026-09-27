/// 동화 생성 마법사(1~3단계)가 화면 사이에서 들고 다니는 입력값.
///
/// 화면은 `Navigator.push`로 다음 단계에 이 객체를 그대로 넘기고, 각 단계는
/// 자신이 입력받은 값만 채운다. 실제 API 호출(캐릭터 생성 → 동화 생성)은
/// 마지막 단계(`StoryResultScreen`)에서 한다.
class StoryCreatePayload {
  // 1단계: 캐릭터
  String? characterMethod;

  /// '기존 캐릭터 선택'일 때 목록에서 고른 캐릭터.
  int? existingCharacterId;
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
    this.existingCharacterId,
    this.characterName,
    this.characterPersonality,
    this.characterDescription,
    this.imageStyle,
    this.location,
    this.event,
    this.keyword,
  });
}
