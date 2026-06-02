// Lightweight FFI interface placeholder for whisper.cpp
class WhisperFFI {
  WhisperFFI._private();
  static final WhisperFFI instance = WhisperFFI._private();

  Future<void> init() async {
    // TODO: load native library and initialize
  }

  Future<String> transcribePath(String audioPath) async {
    // TODO: transcribe audio file
    return 'transcription stub';
  }
}
