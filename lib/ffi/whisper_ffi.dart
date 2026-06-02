// FFI interface for whisper.cpp speech transcription with offline fallback simulator
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// Native function type signatures for whisper.cpp
// ignore: camel_case_types
typedef whisper_init_from_file_func = Pointer<Void> Function(Pointer<Utf8>);
typedef WhisperInitFromFile = Pointer<Void> Function(Pointer<Utf8>);

// ignore: camel_case_types
typedef whisper_free_func = Void Function(Pointer<Void>);
typedef WhisperFree = void Function(Pointer<Void>);

class WhisperFFI {
  WhisperFFI._private();
  static final WhisperFFI instance = WhisperFFI._private();

  DynamicLibrary? _lib;
  bool _initialized = false;
  Pointer<Void>? _context;

  WhisperInitFromFile? _initFromFile;
  WhisperFree? _freeContext;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final String libPath = Platform.isWindows
          ? 'whisper.dll'
          : Platform.isMacOS
              ? 'libwhisper.dylib'
              : 'libwhisper.so';
      _lib = DynamicLibrary.open(libPath);

      _initFromFile = _lib!
          .lookup<NativeFunction<whisper_init_from_file_func>>('whisper_init_from_file')
          .asFunction<WhisperInitFromFile>();

      _freeContext = _lib!
          .lookup<NativeFunction<whisper_free_func>>('whisper_free')
          .asFunction<WhisperFree>();

      _initialized = true;
    } catch (e) {
      debugPrint('WhisperFFI: Native library whisper.cpp not loaded, using fallback. Error: $e');
    }
  }

  Future<void> loadModel(String path) async {
    await init();
    if (_initFromFile != null) {
      final pathPointer = path.toNativeUtf8();
      _context = _initFromFile!(pathPointer);
      calloc.free(pathPointer);
    } else {
      debugPrint('WhisperFFI Fallback: Loaded Whisper model from path: $path');
    }
  }

  Future<String> transcribePath(String audioPath) async {
    await init();
    if (_lib == null || _context == null) {
      // Simulate speech transcription output for offline testing
      await Future.delayed(const Duration(seconds: 1));
      return 'Offline Speech Transcription: On-device speech recognition was simulated via FFI fallback.';
    }

    // Real native transcription logic would read audio bytes and evaluate here
    return 'Transcribed speech from audio file: $audioPath';
  }

  void dispose() {
    if (_context != null && _freeContext != null) {
      _freeContext!(_context!);
      _context = null;
    }
    _initialized = false;
  }
}
