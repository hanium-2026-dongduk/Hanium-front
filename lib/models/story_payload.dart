class StoryCreatePayload {
  // 1단계 (캐릭터 생성) 데이터
  String? characterMethod;
  String? characterName;
  String? characterPersonality;
  String? characterDescription;
  String? imageStyle;

  // 2단계 (장소/사건) 데이터
  String? location;
  String? event;

  // 3단계 (상세 키워드) 데이터
  String? keyword;

  StoryCreatePayload({
    this.characterMethod,
    this.characterName,
    this.characterPersonality,
    this.characterDescription,
    this.imageStyle,
    this.location,
    this.event,
    this.keyword,
  });

  // 백엔드로 보낼 때 JSON으로 쉽게 변환
  Map<String, dynamic> toJson() {
    return {
      'characterMethod': characterMethod,
      'characterName': characterName,
      'characterPersonality': characterPersonality,
      'characterDescription': characterDescription,
      'imageStyle': imageStyle,
      'location': location,
      'event': event,
      'keyword': keyword,
    };
  }
}