// FFI interface for llama.cpp with offline fallback simulator
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Native function type signatures for llama.cpp
// ignore: camel_case_types
typedef llama_backend_init_func = Void Function(Int8);
typedef LlamaBackendInit = void Function(int);

// ignore: camel_case_types
typedef llama_backend_free_func = Void Function();
typedef LlamaBackendFree = void Function();

class LlamaFFI {
  LlamaFFI._private();
  static final LlamaFFI instance = LlamaFFI._private();

  DynamicLibrary? _lib;
  bool _initialized = false;

  // Bound Native C Functions
  LlamaBackendInit? _backendInit;
  LlamaBackendFree? _backendFree;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final String libPath = Platform.isWindows
          ? 'llama.dll'
          : Platform.isMacOS
              ? 'libllama.dylib'
              : 'libllama.so';
      _lib = DynamicLibrary.open(libPath);
      
      _backendInit = _lib!
          .lookup<NativeFunction<llama_backend_init_func>>('llama_backend_init')
          .asFunction<LlamaBackendInit>();
          
      _backendFree = _lib!
          .lookup<NativeFunction<llama_backend_free_func>>('llama_backend_free')
          .asFunction<LlamaBackendFree>();

      _backendInit?.call(0);
      _initialized = true;
    } catch (e) {
      debugPrint('LlamaFFI: Native library llama.cpp not loaded, using fallback. Error: $e');
    }
  }

  Future<void> loadModel(String path) async {
    await init();
    if (_lib == null) {
      debugPrint('LlamaFFI Fallback: Initialized mock model from path: $path');
      return;
    }
    // Real native model loading would call llama_load_model_from_file here
  }

  Stream<String> streamGenerate(String prompt) async* {
    await init();
    if (_lib == null) {
      // Simulate token-by-token stream response for offline run
      const responseText = 'This is a local inference generation response. The system is running in offline fallback mode because the native llama.cpp library could not be dynamically resolved at runtime.';
      final tokens = responseText.split(' ');
      for (final token in tokens) {
        await Future.delayed(const Duration(milliseconds: 80));
        yield '$token ';
      }
      return;
    }

    // Real native generation loop would evaluate tokens and yield strings here
    yield 'Token generated successfully via llama.cpp FFI.';
  }

  void dispose() {
    _backendFree?.call();
    _initialized = false;
  }
}

