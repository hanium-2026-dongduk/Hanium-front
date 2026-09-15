import 'package:flutter_tts/flutter_tts.dart';

/// 단어 발음 재생. (P-ED-VB02)
///
/// 백엔드에는 동화 페이지용 TTS(`services/ai/tts.service.js`)만 있고 단어 단위
/// TTS 엔드포인트가 없어서, 이 기능은 온디바이스 `flutter_tts`로 처리한다.
/// 네트워크 없이 즉시 재생되고, 외부 AI API를 직접 호출하는 것도 아니라
/// AGENTS.md §3의 "외부 AI API 클라이언트 직접 호출 금지" 규칙에도 걸리지 않는다.
///
/// 앱 전체가 인스턴스 하나를 공유한다. `main.dart`의 `_MyAppState.dispose()`에서
/// 반드시 [dispose]를 호출해 재생 중인 음성을 멈춰야 한다. (AGENTS.md §2.2-1 수명주기 해제)
class TtsService {
  final FlutterTts _tts;

  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts() {
    _tts.setLanguage('en-US');
    // 아동이 듣기 편하도록 기본 속도보다 약간 느리게 재생한다.
    _tts.setSpeechRate(0.4);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
    // speak()가 재생 완료까지 기다리도록 해서, 버튼 연타로 발음이 겹치지 않게 한다.
    _tts.awaitSpeakCompletion(true);
  }

  Future<void> speak(String word) async {
    if (word.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(word);
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() => _tts.stop();
}
