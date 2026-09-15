import 'json_parse.dart';

/// 미션 종류. 백엔드 `missionType`이 내려주는 값과 같아야 한다.
/// (Hanium-back `src/config/missionCatalog.js`)
enum MissionType {
  attendance('attendance', '오늘 출석하기'),
  storyRead('story_read', '동화 1편 읽기'),
  wordClicked('word_clicked', '단어 5개 모으기'),
  quizAnswered('quiz_answered', '퀴즈 1문제 풀기');

  final String wireValue;
  final String label;

  const MissionType(this.wireValue, this.label);

  static MissionType fromWire(Object? value) {
    return MissionType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => MissionType.attendance,
    );
  }
}

/// 미션 진행 상태. 서버가 `completed`(지급 직전 과도 상태)를 따로 두지만,
/// 화면에서는 `rewarded`와 묶어 "완료"로만 보여주면 된다. (API_SPEC_REWARD.md 4절)
enum MissionStatus {
  pending('pending'),
  completed('completed'),
  rewarded('rewarded');

  final String wireValue;

  const MissionStatus(this.wireValue);

  static MissionStatus fromWire(Object? value) {
    return MissionStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => MissionStatus.pending,
    );
  }

  /// 화면에서는 completed/rewarded를 구분하지 않고 "완료"로 묶어 표시한다.
  bool get isDone => this != MissionStatus.pending;
}

/// 오늘의 미션 한 항목. (P-GM-RW01)
///
/// **주의**: 이 도메인에는 "보상받기" 버튼이 성립하지 않는다. `progressCount`가
/// `targetCount`에 도달하는 순간 서버가 자동으로 포인트를 지급한다
/// (`API_SPEC_REWARD.md` 4절, "개발자 B 연동 계약" 참고). 화면은 진행도와
/// 완료 여부만 보여주면 된다.
class DailyMission {
  final MissionType type;
  final int targetCount;
  final int progressCount;
  final int rewardPoints;
  final MissionStatus status;

  const DailyMission({
    required this.type,
    required this.targetCount,
    required this.progressCount,
    required this.rewardPoints,
    required this.status,
  });

  double get progress => targetCount == 0 ? 0 : (progressCount / targetCount).clamp(0, 1);

  factory DailyMission.fromJson(Map<String, dynamic> json) => DailyMission(
    type: MissionType.fromWire(json['missionType']),
    targetCount: parseId(json['targetCount']),
    // /missions(카탈로그)에는 progressCount가 없다. 그때는 0으로 둔다.
    progressCount: parseId(json['progressCount']),
    rewardPoints: parseId(json['rewardPoints']),
    status: MissionStatus.fromWire(json['status']),
  );
}
