import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceState { idle, listening, thinking, speaking }

typedef VoiceStateCallback = void Function(VoiceState state);
typedef TranscriptCallback = void Function(String text);

class VoicePipeline {
  VoicePipeline._();
  static final VoicePipeline instance = VoicePipeline._();

  final _tts = FlutterTts();
  final _stt = stt.SpeechToText();

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  bool _sttInitialized = false;
  bool _ttsInitialized = false;

  VoiceStateCallback? onStateChanged;
  TranscriptCallback? onTranscript;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _initTts();
    await _initStt();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => _setState(VoiceState.idle));
    _ttsInitialized = true;
  }

  Future<void> _initStt() async {
    _sttInitialized = await _stt.initialize(
      onError: (e) => _setState(VoiceState.idle),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_state == VoiceState.listening) _setState(VoiceState.thinking);
        }
      },
    );
  }

  // ── Listen (STT) ─────────────────────────────────────────────────────────
  Future<void> startListening() async {
    if (!_sttInitialized) return;
    if (_state == VoiceState.speaking) await _tts.stop();
    _setState(VoiceState.listening);

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          onTranscript?.call(result.recognizedWords);
          _setState(VoiceState.thinking);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        partialResults: false,
      ),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _setState(VoiceState.idle);
  }

  // ── Speak (TTS) ───────────────────────────────────────────────────────────
  Future<void> speak(String text) async {
    if (!_ttsInitialized || text.isEmpty) return;
    _setState(VoiceState.speaking);
    // Strip markdown for cleaner speech
    final cleaned = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), 'code block')
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .trim();
    await _tts.speak(cleaned);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _setState(VoiceState.idle);
  }

  // ── Toggle ────────────────────────────────────────────────────────────────
  Future<void> toggle() async {
    switch (_state) {
      case VoiceState.idle:
        await startListening();
      case VoiceState.listening:
        await stopListening();
      case VoiceState.speaking:
        await stopSpeaking();
      case VoiceState.thinking:
        break;
    }
  }

  // ── TTS settings ─────────────────────────────────────────────────────────
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);
  Future<List<dynamic>> getVoices() async => await _tts.getVoices as List<dynamic>;
  Future<void> setVoice(String name, String locale) => _tts.setVoice({'name': name, 'locale': locale});

  // ── Private ───────────────────────────────────────────────────────────────
  void _setState(VoiceState s) {
    _state = s;
    onStateChanged?.call(s);
  }

  Future<void> dispose() async {
    await _tts.stop();
    await _stt.stop();
  }
}
