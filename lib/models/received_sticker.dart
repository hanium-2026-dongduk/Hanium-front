import 'json_parse.dart';

/// 보호자가 보내 준 칭찬 스티커 한 건. (P-MY-MP05)
///
/// `GET /stickers/received/:childId`의 응답이라 필드가 snake_case다.
class ReceivedSticker {
  final int stickerSendId;
  final String stickerCode;
  final String name;
  final String? iconKey;
  final String? message;
  final DateTime? sentAt;

  const ReceivedSticker({
    required this.stickerSendId,
    required this.stickerCode,
    required this.name,
    this.iconKey,
    this.message,
    this.sentAt,
  });

  factory ReceivedSticker.fromJson(Map<String, dynamic> json) => ReceivedSticker(
    stickerSendId: parseId(json['sticker_send_id']),
    stickerCode: json['sticker_code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    iconKey: json['icon_key'] as String?,
    message: json['message'] as String?,
    // 서버가 UTC로 내려주므로 화면 표시 전에 로컬로 바꾼다.
    sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '')?.toLocal(),
  );
}
