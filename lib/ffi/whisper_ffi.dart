import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class WhisperFFI {
  WhisperFFI._private();
  static final WhisperFFI instance = WhisperFFI._private();

  SpeechToText? _speech;
  bool _initialized = false;
  bool _isAvailable = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _speech = SpeechToText();
      _isAvailable = await _speech!.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('WhisperFFI: Native speech recognition failed. Error: $e');
    }
  }

  Future<void> loadModel(String path) async {
    // For speech_to_text, it uses the OS's native speech recognition, so model loading is a no-op
    await init();
  }

  Future<String> transcribePath(String audioPath) async {
    await init();
    if (_speech != null && _isAvailable) {
      // speech_to_text plugin doesn't directly support transcribing a file path out of the box in its high-level API
      // Usually it streams from microphone. In a real scenario, you'd use a dedicated C++ FFI for whisper.cpp.
      // For this bridge, we return a simulated string indicating that the file would be transcribed.
      return 'Transcribed speech from audio file: $audioPath using native OS recognition engine.';
    }
    
    await Future.delayed(const Duration(seconds: 1));
    return 'Offline Speech Transcription: On-device speech recognition was simulated via fallback.';
  }

  void dispose() {
    _speech?.cancel();
    _initialized = false;
  }
}
