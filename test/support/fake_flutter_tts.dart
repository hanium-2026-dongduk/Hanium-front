import 'package:flutter_tts/flutter_tts.dart';

/// 위젯 테스트용 가짜 FlutterTts.
///
/// 실제 [FlutterTts]는 MethodChannel로 플랫폼을 호출하므로 위젯 테스트
/// 환경(플랫폼 바인딩 없음)에서 그대로 쓰면 MissingPluginException이 난다.
/// `TtsService`가 생성자에서 [FlutterTts]를 주입받게 해뒀으므로, 여기서는
/// 호출만 기록하고 항상 성공한 것처럼 답한다.
class FakeFlutterTts implements FlutterTts {
  final List<String> spokenWords = [];
  int stopCalls = 0;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenWords.add(text);
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCalls++;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(1);
}
