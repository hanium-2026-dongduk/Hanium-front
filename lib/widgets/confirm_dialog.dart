import 'package:flutter/material.dart';

/// 삭제 등 되돌릴 수 없는 동작 전에 확인을 받는 공통 다이얼로그.
///
/// `profile_list_screen.dart`의 삭제 확인 다이얼로그를 승격한 것이다.
/// `VB03_DEL_01`(단어 삭제는 확인 팝업 필수)처럼 삭제 동작이 있는 화면이면
/// 전부 이 다이얼로그를 쓴다.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String cancelLabel = '취소',
  String confirmLabel = '삭제',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
