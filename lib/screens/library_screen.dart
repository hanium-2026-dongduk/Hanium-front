import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hanium_front/core/api_config.dart';
import 'package:hanium_front/models/story.dart';
import 'package:hanium_front/providers/active_child_provider.dart';
import 'package:hanium_front/providers/library_provider.dart';
import 'package:hanium_front/screens/story_result_screen.dart';
import 'package:hanium_front/services/story_service.dart';
import 'package:hanium_front/theme/theme.dart';
import 'package:hanium_front/widgets/async_state_view.dart';

/// 표지 이미지가 없어서(back#40 4번) 그 대신 돌려 보여주는 아이콘들.
const _coverIcons = [
  Icons.auto_stories,
  Icons.nightlight_round,
  Icons.cloud,
  Icons.park,
  Icons.sailing,
  Icons.rocket_launch,
];

/// 내 라이브러리. (P-LB01~05)
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final childProfileId = context.read<ActiveChildProvider>().childProfileId;
    if (childProfileId == null) {
      return Scaffold(
        backgroundColor: AppTheme.navyColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: SafeArea(
          child: CenteredMessage(
            message: '먼저 자녀 프로필을 선택해 주세요.',
            actionLabel: '돌아가기',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<LibraryProvider>(
      create: (context) => LibraryProvider(
        storyService: context.read<StoryService>(),
        childProfileId: childProfileId,
      )..load(),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 삭제 모드 상태 변수
  bool _isDeleteMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 삭제 확인 팝업
  Future<void> _showDeleteConfirmDialog(StorySummary story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '동화 삭제',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.navyColor,
            ),
          ),
          content: Text(
            '\'${story.title}\'를 라이브러리에서 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<LibraryProvider>().deleteStory(story.storyId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '동화가 삭제되었습니다.' : '삭제에 실패했어요. 다시 시도해 주세요.')),
    );
  }

  Future<void> _toggleFavorite(
      LibraryProvider provider,
      StorySummary story,
      ) async {
    final ok = await provider.toggleFavorite(story);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('즐겨찾기 변경에 실패했어요.')));
    }
  }

  void _openStory(StorySummary story) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryResultScreen(
          storyId: story.storyId,
          initialIsFavorite: story.isFavorite,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    final displayedStories = _searchQuery.isEmpty
        ? provider.stories
        : provider.stories
        .where(
          (s) =>
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()),
    )
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '동화 제목을 검색하세요...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        )
            : const Text(
          'MY LIBRARY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              provider.showOnlyFavorites
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: provider.showOnlyFavorites
                  ? AppTheme.pastelPink
                  : Colors.white,
            ),
            onPressed: () =>
                provider.setShowOnlyFavorites(!provider.showOnlyFavorites),
          ),
          // 삭제 모드 토글 버튼
          IconButton(
            icon: Icon(
              _isDeleteMode ? Icons.delete_forever : Icons.delete_outline,
              color: _isDeleteMode ? Colors.redAccent : Colors.white,
            ),
            onPressed: () => setState(() => _isDeleteMode = !_isDeleteMode),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 삭제 모드 활성화 시 안내 텍스트
                  _isDeleteMode
                      ? const Text(
                    '삭제할 동화를 선택하세요.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : const SizedBox.shrink(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1), // withOpacity 대체
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: provider.sortOption,
                        dropdownColor: AppTheme.navyColor,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'CookieRun',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'latest', child: Text('최신순')),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('오래된순'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) provider.setSortOption(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncStateView(
                isLoading: provider.isLoading,
                errorMessage: provider.loadError,
                onRetry: provider.load,
                isEmpty: provider.isEmpty,
                emptyMessage: '아직 만든 동화가 없어요.\n첫 동화를 만들어 볼까요?',
                contentBuilder: (context) => displayedStories.isEmpty
                    ? const Center(
                  child: Text(
                    '해당하는 동화가 없습니다.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.only(
                    left: 32.0,
                    right: 32.0,
                    top: 16.0,
                    bottom: 40.0,
                  ),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 28,
                    mainAxisSpacing: 40,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: displayedStories.length,
                  itemBuilder: (context, index) =>
                      _buildStoryCard(provider, displayedStories[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCard(LibraryProvider provider, StorySummary story) {
    final coverIcon = _coverIcons[story.storyId % _coverIcons.length];
    final isTogglingFavorite = provider.isTogglingFavorite(story.storyId);
    final isDeleting = provider.isDeleting(story.storyId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4), // withOpacity 대체
            blurRadius: 12,
            offset: const Offset(6, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 14,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08), // withOpacity 대체
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.pastelBlue,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                        ),
                      ),
                      // ✨ 여기서부터 썸네일 표시 로직 추가
                      child: story.coverImageUrl != null && story.coverImageUrl!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                        ),
                        child: Image.network(
                          ApiConfig.resolveMediaUrl(story.coverImageUrl!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          // 이미지 로딩 실패 시 기존 아이콘 표시
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              coverIcon,
                              size: 64,
                              color: AppTheme.navyColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      )
                          : Center(
                        child: Icon(
                          coverIcon,
                          size: 64,
                          color: AppTheme.navyColor.withValues(alpha: 0.5), // withOpacity 대체
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: isTogglingFavorite
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : IconButton(
                        icon: Icon(
                          story.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: story.isFavorite
                              ? AppTheme.pastelPink
                              : Colors.white,
                        ),
                        onPressed: () => _toggleFavorite(provider, story),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 12.0,
                    top: 8.0,
                    bottom: 12.0,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            story.title,
                            style: const TextStyle(
                              color: AppTheme.navyColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 삭제 모드 상태에 따라 하단 버튼 동적 변경
                      SizedBox(
                        width: double.infinity,
                        child: isDeleting
                            ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                            : _isDeleteMode
                            ? _buildSmallButton(
                          '삭제',
                          Colors.redAccent,
                              () => _showDeleteConfirmDialog(story),
                        )
                            : _buildSmallButton(
                          '열기',
                          AppTheme.pastelGreen,
                              () => _openStory(story),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String text, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.4), // withOpacity 대체
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
