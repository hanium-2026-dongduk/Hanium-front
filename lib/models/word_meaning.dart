/// 단어 뜻 조회 결과(`GET /api/vocabulary/lookup`). (P-ED-VB01)
///
/// 서버가 앞뒤 문장부호를 떼어낸 단어를 [englishWord]로 돌려준다(`apple,` → `apple`).
/// 필드명이 단어 저장 API(`POST /vocabulary`)와 같아서 그대로 저장에 넘기면 된다.
/// (Hanium-back PR #46 `feat/vocabulary-lookup`, `src/controllers/vocabulary.controller.js` 참고)
class WordMeaning {
  final String englishWord;
  final String koreanMeaning;

  const WordMeaning({required this.englishWord, required this.koreanMeaning});

  factory WordMeaning.fromJson(Map<String, dynamic> json) => WordMeaning(
    englishWord: json['english_word'] as String? ?? '',
    koreanMeaning: json['korean_meaning'] as String? ?? '',
  );
}
