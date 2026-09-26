import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/received_sticker.dart';
import '../services/sticker_service.dart';

/// 받은 칭찬 스티커 목록(MP05)을 페이지 단위로 불러오는 Provider.
class ReceivedStickerProvider extends ChangeNotifier {
  static const int pageLimit = 20;

  final StickerService _stickerService;

  ReceivedStickerProvider({required StickerService stickerService})
    : _stickerService = stickerService;

  final List<ReceivedSticker> _stickers = [];
  int? _loadedChildId;
  int _page = 0;
  bool _hasMore = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  List<ReceivedSticker> get stickers => List.unmodifiable(_stickers);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  /// 첫 페이지부터 다시 불러온다. 당겨서 새로고침에도 쓴다.
  Future<void> load(int childProfileId) async {
    // 같은 자녀를 이미 불러오는 중이면 겹치지 않게 막는다.
    if (_isLoading && _loadedChildId == childProfileId) return;

    // 앱 전역에서 공유되는 Provider라, 자녀가 바뀌면 이전 자녀의 목록이 보이지 않게 비운다.
    if (_loadedChildId != childProfileId) {
      _stickers.clear();
      _page = 0;
      _hasMore = false;
      _isLoadingMore = false;
      _loadedChildId = childProfileId;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _stickerService.fetchReceived(childProfileId, limit: pageLimit);
      // 기다리는 사이 다른 자녀로 바뀌었다면 이 결과는 버린다.
      if (_loadedChildId != childProfileId) return;
      _stickers
        ..clear()
        ..addAll(result.items);
      _page = result.page;
      _hasMore = result.hasMore;
    } on ApiException catch (error) {
      if (_loadedChildId == childProfileId) _errorMessage = error.message;
    } finally {
      if (_loadedChildId == childProfileId) _isLoading = false;
      notifyListeners();
    }
  }

  /// 다음 페이지를 이어 붙인다. 실패해도 이미 보이는 목록은 그대로 둔다.
  Future<void> loadMore(int childProfileId) async {
    if (_loadedChildId != childProfileId) return;
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _stickerService.fetchReceived(
        childProfileId,
        page: _page + 1,
        limit: pageLimit,
      );
      // 기다리는 사이 다른 자녀로 바뀌었다면 이 결과는 버린다.
      if (_loadedChildId != childProfileId) return;
      _stickers.addAll(result.items);
      _page = result.page;
      _hasMore = result.hasMore;
    } on ApiException catch (_) {
      // 스크롤 중 추가 로드 실패는 조용히 넘기고, 다시 스크롤하면 재시도한다.
    } finally {
      if (_loadedChildId == childProfileId) _isLoadingMore = false;
      notifyListeners();
    }
  }
}
