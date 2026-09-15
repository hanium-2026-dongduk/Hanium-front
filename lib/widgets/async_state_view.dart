import 'package:flutter/material.dart';

/// 로딩/에러/빈 상태를 한곳에서 처리하는 공통 화면 껍데기.
///
/// `profile_list_screen.dart`의 private `_CenteredMessage` + 로딩/에러 분기를
/// 승격한 것이다. 단어장·미션·출석·보상 내역 화면이 전부 같은 3단계 상태를
/// 가지므로 여기 모아 재사용한다.
///
/// `RefreshIndicator`로 감쌀 때도 당겨서 새로고침이 되도록, 빈/에러 메시지도
/// 항상 스크롤 가능한 위젯으로 감싼다.
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final String emptyMessage;
  final WidgetBuilder contentBuilder;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
    this.isEmpty = false,
    this.emptyMessage = '아직 내용이 없어요.',
    required this.contentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return CenteredMessage(
        message: errorMessage!,
        actionLabel: onRetry != null ? '다시 시도' : null,
        onAction: onRetry,
      );
    }

    if (isEmpty) {
      return CenteredMessage(message: emptyMessage);
    }

    return contentBuilder(context);
  }
}

/// 화면 가운데에 안내 문구(+선택적 버튼)를 보여준다.
///
/// `RefreshIndicator`가 동작하려면 스크롤 가능한 자식이 있어야 하므로,
/// 빈 상태에서도 당겨서 새로고침이 되도록 스크롤 가능한 컨테이너로 감싼다.
class CenteredMessage extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CenteredMessage({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
