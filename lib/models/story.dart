import 'json_parse.dart';

/// 동화 한 페이지. 이미지·오디오는 서버가 상대경로(`/images/...`, `/audio/...`)로
/// 내려줘서, 실제로 요청할 때는 `ApiConfig.resolveMediaUrl`로 절대 URL을 만들어야 한다.
class StoryPage {
  final int pageNumber;
  final String content;
  final String? imageUrl;
  final String? audioUrl;

  const StoryPage({
    required this.pageNumber,
    required this.content,
    this.imageUrl,
    this.audioUrl,
  });

  factory StoryPage.fromJson(Map<String, dynamic> json) {
    return StoryPage(
      pageNumber: parseId(json['pageNumber']),
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
    );
  }
}

/// 저장된 동화 상세(`GET /api/stories/:id`). 비동기 생성 완료 후에도 이 API로 받는다.
class StoryDetail {
  final int storyId;
  final String title;
  final List<StoryPage> pages;
  final String? characterName;
  final String? background;
  final String? mainEvent;

  /// 다음 이야기 선택지. 이전에 생성된 동화는 빈 배열로 내려올 수 있다.
  final List<String> choices;

  const StoryDetail({
    required this.storyId,
    required this.title,
    required this.pages,
    this.characterName,
    this.background,
    this.mainEvent,
    this.choices = const [],
  });

  factory StoryDetail.fromJson(Map<String, dynamic> json) {
    final pagesJson = json['pages'];
    final pages = pagesJson is List
        ? pagesJson
              .whereType<Map>()
              .map((e) => StoryPage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <StoryPage>[];
    pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

    final settingJson = json['setting'];
    final setting = settingJson is Map
        ? Map<String, dynamic>.from(settingJson)
        : const <String, dynamic>{};

    final choicesJson = json['choices'];
    final choices = choicesJson is List
        ? choicesJson.whereType<String>().toList()
        : <String>[];

    return StoryDetail(
      storyId: parseId(json['storyId']),
      title: json['title'] as String? ?? '',
      pages: pages,
      characterName: json['character'] as String?,
      background: setting['background'] as String?,
      mainEvent: setting['mainEvent'] as String?,
      choices: choices,
    );
  }
}

/// 라이브러리 목록 한 줄. `GET /api/stories`는 표지 이미지나 페이지 수를 주지 않는다.
class StorySummary {
  final int storyId;
  final String title;
  final bool isFavorite;
  final DateTime? createdAt;

  const StorySummary({
    required this.storyId,
    required this.title,
    required this.isFavorite,
    this.createdAt,
  });

  factory StorySummary.fromJson(Map<String, dynamic> json) {
    return StorySummary(
      storyId: parseId(json['storyId']),
      title: json['title'] as String? ?? '',
      isFavorite: json['isFavorite'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
