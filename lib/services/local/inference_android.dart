// Android implementation of local LLM inference using llama_flutter_android.
// Wraps LlamaController which uses llama.cpp with optional Vulkan GPU offload.
// Imported conditionally via `inference_stub.dart if (dart.library.io)`.

import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class InferenceImpl {
  LlamaController? _controller;
  bool _loaded = false;
  String? _loadedModelId;

  bool get supportsLocal => Platform.isAndroid;
  bool get isModelLoaded => _loaded;
  String? get loadedModelId => _loadedModelId;

  Future<GpuInfo> detectGpu() async {
    _controller ??= LlamaController();
    return _controller!.detectGpu();
  }

  Future<void> loadModel({
    required String modelId,
    required String modelPath,
    int? gpuLayers,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Local inference is Android-only.');
    }

    // Unload previous model if switching
    if (_loaded && _loadedModelId != modelId) {
      await dispose();
    }

    if (!_loaded) {
      _controller = LlamaController();
      final gpu = await _controller!.detectGpu();
      await _controller!.loadModel(
        modelPath: modelPath,
        threads: threads,
        contextSize: contextSize,
        gpuLayers: gpuLayers ?? gpu.recommendedGpuLayers,
      );
      _loaded = true;
      _loadedModelId = modelId;
    }
  }

  Stream<String> generateChat({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
    String? template,
  }) {
    if (_controller == null || !_loaded) {
      throw StateError('No model loaded. Call loadModel() first.');
    }
    return _controller!.generateChat(
      messages: messages
          .map((m) => ChatMessage(role: m['role']!, content: m['content']!))
          .toList(),
      temperature: temperature,
      maxTokens: maxTokens,
      template: template,
    );
  }

  Future<void> stopGeneration() async {
    await _controller?.stop();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _loaded = false;
    _loadedModelId = null;
  }
}
