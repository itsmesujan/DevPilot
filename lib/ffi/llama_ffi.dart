import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class LlamaFFI {
  LlamaFFI._private();
  static final LlamaFFI instance = LlamaFFI._private();

  LlamaController? _controller;
  bool _initialized = false;
  String? _currentModelPath;

  Future<void> init() async {
    if (_initialized) return;
    if (Platform.isAndroid) {
      _controller = LlamaController();
      _initialized = true;
    } else {
      debugPrint('LlamaFFI: llama_flutter_android only supports Android. Offline fallback used.');
    }
  }

  Future<void> loadModel(String path) async {
    await init();
    if (_controller != null) {
      if (_currentModelPath == path) return;
      try {
        final gpu = await _controller!.detectGpu();
        await _controller!.loadModel(
          modelPath: path,
          threads: 4,
          contextSize: 2048,
          gpuLayers: gpu.recommendedGpuLayers,
        );
        _currentModelPath = path;
      } catch (e) {
        debugPrint('Error loading native model: $e');
      }
    } else {
      debugPrint('LlamaFFI Fallback: Loaded mock model from path: $path');
    }
  }

  Stream<String> streamGenerate(String prompt) {
    if (_controller != null && _currentModelPath != null) {
      return _controller!.generateChat(
        messages: [ChatMessage(role: 'user', content: prompt)],
        temperature: 0.7,
      );
    } else {
      return _simulateFallback(prompt);
    }
  }

  Stream<String> _simulateFallback(String prompt) async* {
    const responseText = 'This is a local inference generation response. The system is running in offline fallback mode because the native library could not be dynamically resolved at runtime.';
    final tokens = responseText.split(' ');
    for (final token in tokens) {
      await Future.delayed(const Duration(milliseconds: 80));
      yield '$token ';
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _currentModelPath = null;
  }
}
