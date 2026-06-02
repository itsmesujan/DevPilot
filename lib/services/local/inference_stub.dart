// Stub implementation for platforms that don't support local LLM inference
// (Web, desktop without native libs). Imported conditionally.

class GpuInfoStub {
  final bool vulkanSupported;
  final String gpuName;
  final int recommendedGpuLayers;
  final int freeRamBytes;

  const GpuInfoStub({
    this.vulkanSupported = false,
    this.gpuName = 'N/A',
    this.recommendedGpuLayers = 0,
    this.freeRamBytes = 0,
  });
}

class InferenceImpl {
  bool get supportsLocal => false;
  bool get isModelLoaded => false;
  String? get loadedModelId => null;

  Future<GpuInfoStub> detectGpu() async => const GpuInfoStub();

  Future<void> loadModel({
    required String modelId,
    required String modelPath,
    int? gpuLayers,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    throw UnsupportedError(
        'Local LLM inference is not supported on this platform.');
  }

  Stream<String> generateChat({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
    String? template,
  }) {
    throw UnsupportedError(
        'Local LLM inference is not supported on this platform.');
  }

  Future<void> stopGeneration() async {}

  Future<void> dispose() async {}
}
