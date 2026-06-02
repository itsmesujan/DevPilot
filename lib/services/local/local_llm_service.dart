// LocalLlmService — singleton service for on-device GGUF model inference.
//
// Uses llama_flutter_android on Android (llama.cpp + Vulkan GPU offload),
// falls back to a stub on Web/other platforms.
//
// Usage:
//   await LocalLlmService.instance.loadModel(modelId: ..., filename: ...);
//   await for (final token in LocalLlmService.instance.generateChat(...)) { ... }

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'inference_stub.dart'
    if (dart.library.io) 'inference_android.dart';

enum LocalModelState { idle, loading, loaded, error }

class LocalLlmService {
  LocalLlmService._();
  static final LocalLlmService instance = LocalLlmService._();

  final _impl = InferenceImpl();

  LocalModelState _state = LocalModelState.idle;
  String? _error;

  bool get supportsLocal => _impl.supportsLocal;
  bool get isModelLoaded => _impl.isModelLoaded;
  String? get loadedModelId => _impl.loadedModelId;
  LocalModelState get state => _state;
  String? get lastError => _error;

  /// Returns the full filesystem path where a downloaded model is stored.
  Future<String> resolveModelPath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'models', filename);
  }

  /// Detects GPU capabilities (Android only). Returns null on unsupported platforms.
  Future<dynamic> detectGpu() async {
    try {
      return await _impl.detectGpu();
    } catch (_) {
      return null;
    }
  }

  /// Load a GGUF model into memory. If the same model is already loaded, no-ops.
  /// [modelId]  — unique ID matching ModelProfile.id
  /// [filename] — GGUF filename (e.g. "qwen2.5-1.5b-instruct-q4_k_m.gguf")
  /// [gpuLayers] — null = auto-detect via detectGpu()
  /// [threads]  — number of CPU threads (default 4)
  /// [contextSize] — token context window (default 2048)
  Future<void> loadModel({
    required String modelId,
    required String filename,
    int? gpuLayers,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    if (_impl.loadedModelId == modelId && _impl.isModelLoaded) return;

    _state = LocalModelState.loading;
    _error = null;

    try {
      final modelPath = await resolveModelPath(filename);

      if (!File(modelPath).existsSync()) {
        throw Exception(
            'Model file not found at $modelPath. Download it first from Model Hub.');
      }

      await _impl.loadModel(
        modelId: modelId,
        modelPath: modelPath,
        gpuLayers: gpuLayers,
        threads: threads,
        contextSize: contextSize,
      );

      _state = LocalModelState.loaded;
    } catch (e) {
      _state = LocalModelState.error;
      _error = e.toString();
      rethrow;
    }
  }

  /// Stream chat tokens from the loaded local model.
  /// [messages] — list of {"role": "user"|"assistant"|"system", "content": "..."}
  Stream<String> generateChat({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
    String? template,
  }) {
    return _impl.generateChat(
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      template: template,
    );
  }

  /// Stop an in-progress generation.
  Future<void> stopGeneration() => _impl.stopGeneration();

  /// Unload the current model and free native memory.
  Future<void> unloadModel() async {
    await _impl.dispose();
    _state = LocalModelState.idle;
    _error = null;
  }
}
