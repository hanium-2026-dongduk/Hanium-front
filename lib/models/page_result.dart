import 'json_parse.dart';

/// 서버가 페이지네이션과 함께 내려주는 목록 응답의 공통 껍데기.
///
/// 단어장(`GET /vocabulary`)과 보상 이력(`GET /rewards/:childId/history`)이
/// 똑같은 `{ items: [...], pagination: { page, limit, totalCount, totalPages } }`
/// 모양을 쓰므로 한곳에 모았다.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int totalCount;
  final int totalPages;

  const PageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.totalCount,
    required this.totalPages,
  });

  /// 다음 페이지를 더 불러올 수 있는지. 무한 스크롤에서 쓴다.
  bool get hasMore => page < totalPages;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((e) => itemParser(Map<String, dynamic>.from(e))).toList()
        : <T>[];

    final pagination = json['pagination'];
    final paginationMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};

    return PageResult(
      items: items,
      page: parseId(paginationMap['page']) == 0 ? 1 : parseId(paginationMap['page']),
      limit: parseId(paginationMap['limit']) == 0 ? 20 : parseId(paginationMap['limit']),
      totalCount: parseId(paginationMap['totalCount']),
      totalPages: parseId(paginationMap['totalPages']) == 0 ? 1 : parseId(paginationMap['totalPages']),
    );
  }
}
