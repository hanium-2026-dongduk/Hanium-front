import 'package:shared_preferences/shared_preferences.dart';

/// 단어 즐겨찾기 상태를 기기에 로컬로 저장한다. (P-ED-VB04)
///
/// **임시 구현이다.** 백엔드 `vocabulary_entries.is_favorite` 컬럼은 있지만
/// 이를 토글하는 API(`PATCH /vocabulary/:id/favorite`)가 아직 없어서, 서버
/// 대신 기기에 저장한다. 기기를 바꾸거나 앱을 지우면 즐겨찾기가 초기화된다.
/// (백엔드 이슈로 토글 API 추가를 요청해 두었다 — 이슈 등록 후 이 파일을
/// `VocabularyService`의 서버 호출로 교체하면 된다.)
///
/// `TokenStorage`와 같은 방어 원칙을 따른다: 저장소를 못 읽어도 예외를 던지지
/// 않고 빈 결과로 떨어뜨려서, 즐겨찾기 하나 때문에 화면이 통째로 죽지 않게 한다.
class VocabularyFavoriteStore {
  static String _keyFor(int childProfileId) => 'vocab_favorites_$childProfileId';

  /// 이 자녀의 즐겨찾기 단어 ID 집합을 읽는다.
  Future<Set<int>> loadFavoriteIds(int childProfileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_keyFor(childProfileId)) ?? const [];
      return raw.map(int.tryParse).whereType<int>().toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setFavorite(int childProfileId, int vocabularyEntryId, bool isFavorite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyFor(childProfileId);
      final current = (prefs.getStringList(key) ?? const []).toSet();
      if (isFavorite) {
        current.add(vocabularyEntryId.toString());
      } else {
        current.remove(vocabularyEntryId.toString());
      }
      await prefs.setStringList(key, current.toList());
    } catch (_) {
      // 저장에 실패해도 화면 상태(setState)는 이미 바뀌어 있으니 조용히 넘어간다.
      // 다음 앱 재시작 때 서버 목록과 다시 맞춰질 뿐이다.
    }
  }

  /// 서버에 더 이상 존재하지 않는 단어의 즐겨찾기 기록을 정리한다.
  /// 목록을 불러올 때마다 호출해, 삭제된 단어의 흔적이 계속 쌓이지 않게 한다.
  Future<void> pruneMissing(int childProfileId, Set<int> existingIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyFor(childProfileId);
      final current = prefs.getStringList(key) ?? const [];
      final pruned = current.where((id) {
        final parsed = int.tryParse(id);
        return parsed != null && existingIds.contains(parsed);
      }).toList();
      if (pruned.length != current.length) {
        await prefs.setStringList(key, pruned);
      }
    } catch (_) {
      // 정리 실패는 치명적이지 않다 — 다음 기회에 다시 시도된다.
    }
  }
}
