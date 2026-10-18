import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/word_meaning.dart';
import '../services/vocabulary_service.dart';

/// 동화 본문에서 단어를 눌러 뜻을 보고 단어장에 저장한다. (P-ED-VB01)
///
/// **화면 단위 Provider다.** `StoryResultScreen`이 열릴 때마다 새로 만든다.
///
/// 같은 단어가 여러 번 저장되지 않게 두 가지를 막는다.
/// - 연타: 저장 요청이 끝나기 전에는 같은 단어를 다시 보내지 않는다.
/// - 재저장: 자녀 단어장에 이미 있는 단어(대소문자·앞뒤 문장부호 무시)는 저장하지 않는다.
///
/// 서버 `POST /vocabulary`는 중복을 확인하지 않고 매번 새로 만들어서(미션 `word_clicked`도
/// 다시 오른다) 여기서 막는다. 다른 기기에서 동시에 저장하는 경우까지는 막지 못한다.
class WordSaveProvider extends ChangeNotifier {
  final VocabularyService _vocabularyService;
  final int childProfileId;

  WordSaveProvider({
    required VocabularyService vocabularyService,
    required this.childProfileId,
  }) : _vocabularyService = vocabularyService;

  /// 단어장 목록을 한 번에 받는 크기와 최대 쪽수. 서버 limit 상한이 100이다.
  static const int _pageSize = 100;
  static const int _maxPages = 20;

  final Map<String, WordMeaning> _meanings = {};
  final Set<String> _lookingUp = {};
  final Map<String, String> _lookupErrors = {};
  final Set<String> _savedWords = {};
  final Set<String> _saving = {};
  Future<void>? _savedWordsLoading;
  bool _disposed = false;

  /// 누른 토큰을 비교용 키로 바꾼다. 서버 뜻 조회와 같은 규칙으로 앞뒤 문장부호를 떼고
  /// 둥근 따옴표를 통일한 뒤 소문자로 만든다(`"Apple,"` → `apple`). 글자가 없으면 빈 문자열.
  static String normalize(String token) => token
      .trim()
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp(r'^[^A-Za-z]+|[^A-Za-z]+$'), '')
      .toLowerCase();

  WordMeaning? meaningOf(String word) => _meanings[word];
  bool isLookingUp(String word) => _lookingUp.contains(word);
  String? lookupErrorOf(String word) => _lookupErrors[word];
  bool isSaved(String word) => _savedWords.contains(word);
  bool isSaving(String word) => _saving.contains(word);

  /// 자녀 단어장을 받아 이미 저장한 단어를 기억해 둔다. 한 번만 부르고, 실패하면 다음에 다시 시도한다.
  Future<void> loadSavedWords() {
    return _savedWordsLoading ??= _fetchSavedWords();
  }

  Future<void> _fetchSavedWords() async {
    try {
      var page = 1;
      while (page <= _maxPages) {
        final result = await _vocabularyService.fetchEntries(
          childProfileId,
          page: page,
          limit: _pageSize,
        );
        _savedWords.addAll(result.items.map((e) => normalize(e.englishWord)));
        if (!result.hasMore) break;
        page++;
      }
      _safeNotify();
    } on ApiException {
      // 못 받아도 단어 뜻 보기·저장은 할 수 있어야 한다. 다음 저장 때 다시 받는다.
      _savedWordsLoading = null;
    }
  }

  /// [word]([normalize]된 키)의 뜻을 받아 온다. 이미 받았거나 받는 중이면 다시 부르지 않는다.
  Future<void> lookup(String word) async {
    if (word.isEmpty ||
        _meanings.containsKey(word) ||
        _lookingUp.contains(word)) {
      return;
    }
    _lookingUp.add(word);
    _lookupErrors.remove(word);
    _safeNotify();

    try {
      final meaning = await _vocabularyService.lookupMeaning(word);
      _meanings[word] = meaning;
    } on ApiException catch (error) {
      _lookupErrors[word] = error.statusCode == 404
          ? '이 단어의 뜻은 아직 몰라요.'
          : '뜻을 불러오지 못했어요. 다시 눌러 볼까요?';
    } finally {
      _lookingUp.remove(word);
      _safeNotify();
    }
  }

  /// [word]를 단어장에 저장한다. 실패하면 화면에 보여줄 문구를, 그 외에는 null을 돌려준다.
  /// 뜻이 없거나 저장 중이거나 이미 저장한 단어면 아무것도 하지 않는다.
  Future<String?> save(String word, {int? storyId}) async {
    final meaning = _meanings[word];
    if (meaning == null ||
        _saving.contains(word) ||
        _savedWords.contains(word)) {
      return null;
    }
    _saving.add(word);
    _safeNotify();

    try {
      // 화면을 열자마자 누르면 단어장 목록이 아직 안 왔을 수 있다. 받은 뒤 다시 확인한다.
      await loadSavedWords();
      if (_savedWords.contains(word)) return null;

      final entry = await _vocabularyService.saveEntry(
        childProfileId: childProfileId,
        storyId: storyId,
        englishWord: meaning.englishWord,
        koreanMeaning: meaning.koreanMeaning,
      );
      _savedWords
        ..add(word)
        ..add(normalize(entry.englishWord));
      return null;
    } on ApiException {
      return '단어를 저장하지 못했어요. 잠시 후 다시 해 볼까요?';
    } finally {
      _saving.remove(word);
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
