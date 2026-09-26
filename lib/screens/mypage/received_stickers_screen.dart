import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/received_sticker.dart';
import '../../providers/active_child_provider.dart';
import '../../providers/received_sticker_provider.dart';
import '../../theme/theme.dart';
import '../../utils/reward_icons.dart';
import '../../widgets/async_state_view.dart';

/// 마이페이지 > 칭찬 스티커. 보호자가 보내 준 스티커 목록. (P-MY-MP05)
class ReceivedStickersScreen extends StatefulWidget {
  const ReceivedStickersScreen({super.key});

  @override
  State<ReceivedStickersScreen> createState() => _ReceivedStickersScreenState();
}

class _ReceivedStickersScreenState extends State<ReceivedStickersScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _childProfileId;

  @override
  void initState() {
    super.initState();
    _childProfileId = context.read<ActiveChildProvider>().childProfileId;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _childProfileId;
    if (id == null || !mounted) return;
    await context.read<ReceivedStickerProvider>().load(id);
  }

  void _onScroll() {
    final id = _childProfileId;
    if (id == null || !_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<ReceivedStickerProvider>().loadMore(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceivedStickerProvider>();
    final stickers = provider.stickers;

    return Scaffold(
      backgroundColor: AppTheme.navyColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '칭찬 스티커',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _childProfileId == null
            ? const CenteredMessage(message: '먼저 자녀 프로필을 선택해 주세요.')
            : RefreshIndicator(
                onRefresh: _load,
                child: AsyncStateView(
                  isLoading: provider.isLoading && stickers.isEmpty,
                  errorMessage: stickers.isEmpty ? provider.errorMessage : null,
                  onRetry: _load,
                  isEmpty: stickers.isEmpty,
                  emptyMessage: '아직 받은 칭찬 스티커가 없어요',
                  contentBuilder: (_) => ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: stickers.length + (provider.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      if (index >= stickers.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _StickerTile(sticker: stickers[index]);
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  final ReceivedSticker sticker;

  const _StickerTile({required this.sticker});

  @override
  Widget build(BuildContext context) {
    final color = RewardIcons.colorFor(sticker.iconKey);
    final message = sticker.message;
    final sentAt = sticker.sentAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(RewardIcons.iconFor(sticker.iconKey), color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sticker.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                ],
                if (sentAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(sentAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
