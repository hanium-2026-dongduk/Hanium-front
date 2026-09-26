import 'package:flutter_test/flutter_test.dart';
import 'package:hanium_front/models/dashboard_summary.dart';
import 'package:hanium_front/models/received_sticker.dart';

/// 마이페이지 모델의 필드 이름·케이스 계약.
/// 스티커는 snake_case, 대시보드는 camelCase다.
void main() {
  group('ReceivedSticker 직렬화는', () {
    test('snake_case 필드를 읽는다', () {
      final sticker = ReceivedSticker.fromJson({
        'sticker_send_id': 3,
        'sticker_code': 'hug',
        'name': '안아주기',
        'icon_key': 'hug',
        'message': '고마워',
        'sent_at': '2026-09-01T00:00:00.000Z',
      });

      expect(sticker.stickerSendId, 3);
      expect(sticker.stickerCode, 'hug');
      expect(sticker.name, '안아주기');
      expect(sticker.iconKey, 'hug');
      expect(sticker.message, '고마워');
      expect(sticker.sentAt, DateTime.utc(2026, 9, 1).toLocal());
    });

    test('BIGINT id가 문자열로 와도 정수로 읽는다', () {
      expect(ReceivedSticker.fromJson({'sticker_send_id': '42'}).stickerSendId, 42);
    });

    test('선택 필드가 없으면 null·빈 문자열로 읽는다', () {
      final sticker = ReceivedSticker.fromJson({'sticker_send_id': 1});

      expect(sticker.name, '');
      expect(sticker.stickerCode, '');
      expect(sticker.iconKey, isNull);
      expect(sticker.message, isNull);
      expect(sticker.sentAt, isNull);
    });

    test('날짜 형식이 어긋나면 sentAt은 null이다', () {
      expect(ReceivedSticker.fromJson({'sent_at': 'yesterday'}).sentAt, isNull);
    });
  });

  group('DashboardSummary 직렬화는', () {
    test('camelCase 집계와 퀴즈 통계를 읽는다', () {
      final summary = DashboardSummary.fromJson({
        'storyCount': 4,
        'favoriteStoryCount': 1,
        'vocabularyCount': 9,
        'quizStats': {
          'totalAttempts': 2,
          'averageScore': 90,
          'lastAttemptAt': '2026-09-10T00:00:00.000Z',
        },
      });

      expect(summary.storyCount, 4);
      expect(summary.favoriteStoryCount, 1);
      expect(summary.vocabularyCount, 9);
      expect(summary.quizStats.totalAttempts, 2);
      expect(summary.quizStats.averageScore, 90.0);
      expect(summary.quizStats.lastAttemptAt, DateTime.utc(2026, 9, 10).toLocal());
    });

    test('quizStats가 없으면 응시 0회로 읽는다', () {
      final summary = DashboardSummary.fromJson({'storyCount': 1});

      expect(summary.quizStats.totalAttempts, 0);
      expect(summary.quizStats.averageScore, isNull);
      expect(summary.vocabularyCount, 0);
    });
  });
}
