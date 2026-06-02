import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsFFI {
  TtsFFI._private();
  static final TtsFFI instance = TtsFFI._private();

  FlutterTts? _flutterTts;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage("en-US");
      await _flutterTts!.setSpeechRate(0.5);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('TtsFFI: Native TTS initialization failed. Error: $e');
    }
  }

  Future<void> speak(String text) async {
    await init();
    if (_flutterTts != null) {
      await _flutterTts!.speak(text);
    } else {
      debugPrint('TtsFFI Offline Speech Synthesis: $text');
    }
  }

  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  void dispose() {
    stop();
    _initialized = false;
  }
}
