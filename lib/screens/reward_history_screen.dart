import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../models/reward_history_entry.dart';
import '../providers/active_child_provider.dart';
import '../services/reward_service.dart';
import '../theme/theme.dart';
import '../widgets/async_state_view.dart';

/// 보상 내역 화면. (P-GM-RW03)
///
/// 메뉴 구성도상 정식 경로는 `마이페이지 > 보상 현황 > 보상 내역`이지만
/// 마이페이지 화면이 아직 없어(#18), 메인 화면 상단 토큰 칩에서 진입한다.
class RewardHistoryScreen extends StatefulWidget {
  const RewardHistoryScreen({super.key});

  @override
  State<RewardHistoryScreen> createState() => _RewardHistoryScreenState();
}

class _RewardHistoryScreenState extends State<RewardHistoryScreen> {
  static const _pageLimit = 20;

  final ScrollController _scrollController = ScrollController();

  List<RewardHistoryEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = false;

  /// null이면 전체.
  RewardReason? _selectedReason;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      final result = await context.read<RewardService>().fetchHistory(
        childProfileId,
        page: 1,
        limit: _pageLimit,
        reason: _selectedReason?.wireValue,
      );
      if (!mounted) return;
      setState(() {
        _entries = result.items;
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
      final result = await context.read<RewardService>().fetchHistory(
        childProfileId,
        page: _page + 1,
        limit: _pageLimit,
        reason: _selectedReason?.wireValue,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(result.items);
        _page = result.page;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _selectReason(RewardReason? reason) {
    setState(() => _selectedReason = reason);
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('보상 내역', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFirstPage,
                child: AsyncStateView(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  onRetry: _loadFirstPage,
                  isEmpty: _entries.isEmpty,
                  emptyMessage: '아직 받은 보상이 없어요.',
                  contentBuilder: (_) => ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    itemCount: _entries.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= _entries.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildHistoryTile(_entries[index]);
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

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        children: [
          _buildFilterChip(null, '전체'),
          for (final reason in RewardReason.values) _buildFilterChip(reason, reason.label),
        ],
      ),
    );
  }

  Widget _buildFilterChip(RewardReason? reason, String label) {
    final selected = _selectedReason == reason;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectReason(reason),
        selectedColor: AppTheme.yellowColor,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        labelStyle: TextStyle(
          color: selected ? AppTheme.navyColor : Colors.white70,
          fontWeight: FontWeight.bold,
        ),
        checkmarkColor: AppTheme.navyColor,
        side: BorderSide(color: selected ? Colors.transparent : Colors.white24),
      ),
    );
  }

  Widget _buildHistoryTile(RewardHistoryEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppTheme.pastelPurple, shape: BoxShape.circle),
            child: const Icon(Icons.stars, color: AppTheme.navyColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason?.description ?? '기타 보상',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(_formatDateTime(entry.createdAt), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${entry.points} 토큰', style: const TextStyle(color: AppTheme.yellowColor, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('잔액 ${entry.balanceAfter}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}.${_twoDigits(dateTime.month)}.${_twoDigits(dateTime.day)}  '
        '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
