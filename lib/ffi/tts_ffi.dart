// Lightweight FFI interface placeholder for on-device TTS
class TtsFFI {
  TtsFFI._private();
  static final TtsFFI instance = TtsFFI._private();

  Future<void> init() async {}
  Future<void> speak(String text) async {}
}
