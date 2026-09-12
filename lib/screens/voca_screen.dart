import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/vocabulary_favorite_store.dart';
import '../models/vocabulary_entry.dart';
import '../providers/active_child_provider.dart';
import '../services/tts_service.dart';
import '../services/vocabulary_service.dart';
import '../theme/theme.dart';
import '../widgets/async_state_view.dart';
import '../widgets/confirm_dialog.dart';

/// 내 단어장 화면. (P-ED-VB01 목록 조회, VB02 발음 재생, VB03 삭제, VB04 즐겨찾기)
class VocaScreen extends StatefulWidget {
  const VocaScreen({super.key});

  @override
  State<VocaScreen> createState() => _VocaScreenState();
}

class _VocaScreenState extends State<VocaScreen> {
  static const _pageLimit = 20;

  final ScrollController _scrollController = ScrollController();
  final VocabularyFavoriteStore _favoriteStore = VocabularyFavoriteStore();

  List<VocabularyEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = false;

  /// 즐겨찾기만 보기 필터. (VB04_FAV_02)
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 첫 프레임 이후에 자녀 정보를 읽어야 Provider가 준비된다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  int? get _childProfileId => context.read<ActiveChildProvider>().childProfileId;

  Future<void> _loadFirstPage() async {
    final childProfileId = _childProfileId;
    if (childProfileId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '먼저 자녀 프로필을 선택해 주세요.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<VocabularyService>();
      final result = await service.fetchEntries(childProfileId, page: 1, limit: _pageLimit);
      final favorites = await _favoriteStore.loadFavoriteIds(childProfileId);
      await _favoriteStore.pruneMissing(
        childProfileId,
        result.items.map((e) => e.vocabularyEntryId).toSet(),
      );

      if (!mounted) return;
      setState(() {
        _entries = result.items
            .map((e) => e.copyWith(isFavorite: favorites.contains(e.vocabularyEntryId)))
            .toList();
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final childProfileId = _childProfileId;
    if (childProfileId == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final service = context.read<VocabularyService>();
      final nextPage = _page + 1;
      final result = await service.fetchEntries(childProfileId, page: nextPage, limit: _pageLimit);
      final favorites = await _favoriteStore.loadFavoriteIds(childProfileId);

      if (!mounted) return;
      setState(() {
        _entries.addAll(
          result.items.map((e) => e.copyWith(isFavorite: favorites.contains(e.vocabularyEntryId))),
        );
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      _showMessage(error.message);
    }
  }

  Future<void> _toggleFavorite(VocabularyEntry entry) async {
    final childProfileId = _childProfileId;
    if (childProfileId == null) return;

    final newValue = !entry.isFavorite;
    // 로컬 저장이 끝나길 기다리지 않고 먼저 화면을 바꿔 즉각적인 반응을 준다.
    setState(() {
      final index = _entries.indexWhere((e) => e.vocabularyEntryId == entry.vocabularyEntryId);
      if (index != -1) _entries[index] = _entries[index].copyWith(isFavorite: newValue);
    });
    await _favoriteStore.setFavorite(childProfileId, entry.vocabularyEntryId, newValue);
  }

  Future<void> _speak(VocabularyEntry entry) async {
    await context.read<TtsService>().speak(entry.englishWord);
  }

  Future<void> _deleteEntry(VocabularyEntry entry) async {
    final childProfileId = _childProfileId;
    if (childProfileId == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: '단어 삭제',
      content: '"${entry.englishWord}" 단어를 단어장에서 지울까요?',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<VocabularyService>().deleteEntry(entry.vocabularyEntryId, childProfileId);
      if (!mounted) return;
      setState(() {
        _entries.removeWhere((e) => e.vocabularyEntryId == entry.vocabularyEntryId);
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final displayedWords = _showOnlyFavorites
        ? _entries.where((e) => e.isFavorite).toList()
        : _entries;
    final favoriteCount = _entries.where((e) => e.isFavorite).length;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('내 단어장', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.pastelBlue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: AppTheme.pastelBlue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.menu_book, color: AppTheme.navyColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('내가 모은 마법 단어들 ✨', style: TextStyle(color: AppTheme.navyColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '총 ${_entries.length}개 중 $favoriteCount개 즐겨찾기!',
                            style: TextStyle(color: AppTheme.navyColor.withValues(alpha: 0.7), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: const Text('즐겨찾기만'),
                  selected: _showOnlyFavorites,
                  onSelected: (selected) => setState(() => _showOnlyFavorites = selected),
                  selectedColor: AppTheme.yellowColor,
                  backgroundColor: AppTheme.navyColor,
                  labelStyle: TextStyle(
                    color: _showOnlyFavorites ? AppTheme.navyColor : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  checkmarkColor: AppTheme.navyColor,
                  side: BorderSide(
                    color: _showOnlyFavorites ? Colors.transparent : Colors.white54,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFirstPage,
                child: AsyncStateView(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  onRetry: _loadFirstPage,
                  isEmpty: displayedWords.isEmpty,
                  emptyMessage: _showOnlyFavorites
                      ? '즐겨찾기한 단어가 아직 없어요.\n★ 아이콘을 눌러 추가해 보세요.'
                      : '아직 저장된 단어가 없어요.\n동화를 읽다가 모르는 단어를 저장해 보세요.',
                  contentBuilder: (_) => ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    itemCount: displayedWords.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= displayedWords.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildWordCard(displayedWords[index]);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(VocabularyEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: entry.isFavorite ? AppTheme.yellowColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 발음 재생 버튼. (VB02) IconButton 기본 터치 영역이 48dp를 확보한다.
          IconButton(
            onPressed: () => _speak(entry),
            icon: const Icon(Icons.volume_up, color: Colors.white70, size: 24),
            tooltip: '발음 듣기',
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.englishWord,
                  style: const TextStyle(color: AppTheme.yellowColor, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Quicksand'),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.koreanMeaning,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (entry.exampleSentence != null && entry.exampleSentence!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.exampleSentence!,
                    style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),

          // 즐겨찾기 토글. (VB04)
          IconButton(
            onPressed: () => _toggleFavorite(entry),
            icon: Icon(
              entry.isFavorite ? Icons.star : Icons.star_border,
              color: entry.isFavorite ? AppTheme.yellowColor : Colors.white30,
              size: 28,
            ),
            tooltip: '즐겨찾기',
          ),

          // 삭제. (VB03, 확인 팝업 필수)
          IconButton(
            onPressed: () => _deleteEntry(entry),
            icon: const Icon(Icons.delete_outline, color: Colors.white30, size: 24),
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }
}
