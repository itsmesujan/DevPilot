// FFI interface for on-device speech synthesis (TTS) with offline fallback simulator
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// Native function type signatures for TTS library
// ignore: camel_case_types
typedef tts_init_func = Pointer<Void> Function();
typedef TtsInit = Pointer<Void> Function();

// ignore: camel_case_types
typedef tts_speak_func = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef TtsSpeak = void Function(Pointer<Void>, Pointer<Utf8>);

// ignore: camel_case_types
typedef tts_free_func = Void Function(Pointer<Void>);
typedef TtsFree = void Function(Pointer<Void>);

class TtsFFI {
  TtsFFI._private();
  static final TtsFFI instance = TtsFFI._private();

  DynamicLibrary? _lib;
  bool _initialized = false;
  Pointer<Void>? _ttsEngine;

  TtsInit? _ttsInit;
  TtsSpeak? _ttsSpeak;
  TtsFree? _ttsFree;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final String libPath = Platform.isWindows
          ? 'tts.dll'
          : Platform.isMacOS
              ? 'libtts.dylib'
              : 'libtts.so';
      _lib = DynamicLibrary.open(libPath);

      _ttsInit = _lib!
          .lookup<NativeFunction<tts_init_func>>('tts_init')
          .asFunction<TtsInit>();

      _ttsSpeak = _lib!
          .lookup<NativeFunction<tts_speak_func>>('tts_speak')
          .asFunction<TtsSpeak>();

      _ttsFree = _lib!
          .lookup<NativeFunction<tts_free_func>>('tts_free')
          .asFunction<TtsFree>();

      _ttsEngine = _ttsInit!();
      _initialized = true;
    } catch (e) {
      debugPrint('TtsFFI: Native library not loaded, using fallback. Error: $e');
    }
  }

  Future<void> speak(String text) async {
    await init();
    if (_lib == null || _ttsEngine == null) {
      // Fallback speech simulation
      debugPrint('TtsFFI Offline Speech Synthesis: $text');
      return;
    }

    final textPointer = text.toNativeUtf8();
    _ttsSpeak!(_ttsEngine!, textPointer);
    calloc.free(textPointer);
  }

  void dispose() {
    if (_ttsEngine != null && _ttsFree != null) {
      _ttsFree!(_ttsEngine!);
      _ttsEngine = null;
    }
    _initialized = false;
  }
}
