import 'json_parse.dart';

/// 단어장 한 항목. (P-ED-VB01~VB04)
/// 백엔드 경로는 `/api/vocabulary`이고 필드는 snake_case다.
/// (Hanium-back `src/routes/vocabulary.route.js`, `src/models/vocabularyEntry.model.js` 참고)
///
/// **주의**: `isFavorite`는 서버가 컬럼(`is_favorite`)만 갖고 있고 토글하는 API가
/// 아직 없다. 그래서 이 필드는 서버 응답을 읽을 때는 항상 `false`로 오고,
/// 실제 즐겨찾기 여부는 화면이 `VocabularyFavoriteStore`(로컬 저장)에서 따로 구해와
/// `copyWith`로 덮어써서 쓴다. (백엔드 이슈: `PATCH /vocabulary/:id/favorite` 요청 예정)
class VocabularyEntry {
  final int vocabularyEntryId;
  final int childProfileId;

  /// 단어를 저장한 동화. 동화 뷰어에서 저장한 게 아니면 null일 수 있다.
  final int? storyId;

  final String englishWord;
  final String koreanMeaning;
  final String? exampleSentence;

  /// 로컬 즐겨찾기 상태. 서버 응답의 `is_favorite`는 항상 false로 오므로
  /// 화면에서 `VocabularyFavoriteStore` 조회 결과로 덮어써야 실제 값이 된다.
  final bool isFavorite;

  final DateTime createdAt;

  const VocabularyEntry({
    required this.vocabularyEntryId,
    required this.childProfileId,
    this.storyId,
    required this.englishWord,
    required this.koreanMeaning,
    this.exampleSentence,
    this.isFavorite = false,
    required this.createdAt,
  });

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) => VocabularyEntry(
    vocabularyEntryId: parseId(json['vocabulary_entry_id']),
    childProfileId: parseId(json['child_profile_id']),
    storyId: parseOptionalInt(json['story_id']),
    englishWord: json['english_word'] as String? ?? '',
    koreanMeaning: json['korean_meaning'] as String? ?? '',
    exampleSentence: json['example_sentence'] as String?,
    isFavorite: json['is_favorite'] as bool? ?? false,
    // 서버는 UTC로 내려주므로 화면에 표시할 때 헷갈리지 않도록 로컬로 바꿔 보관한다.
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );

  VocabularyEntry copyWith({bool? isFavorite}) => VocabularyEntry(
    vocabularyEntryId: vocabularyEntryId,
    childProfileId: childProfileId,
    storyId: storyId,
    englishWord: englishWord,
    koreanMeaning: koreanMeaning,
    exampleSentence: exampleSentence,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );
}
