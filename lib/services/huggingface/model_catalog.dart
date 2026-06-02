/// Curated catalog of recommended Hugging Face models
/// Organized by category, size, and use case
class ModelCatalog {
  /// Get all curated model categories
  static List<ModelCategory> get categories => [
        ModelCategory(
          id: 'general',
          name: 'General Purpose',
          description: 'Versatile models for general chat and assistance',
          icon: '💬',
          models: _generalModels,
        ),
        ModelCategory(
          id: 'code',
          name: 'Code Generation',
          description: 'Models optimized for programming and code tasks',
          icon: '💻',
          models: _codeModels,
        ),
        ModelCategory(
          id: 'creative',
          name: 'Creative Writing',
          description: 'Models for storytelling, poetry, and creative content',
          icon: '✍️',
          models: _creativeModels,
        ),
        ModelCategory(
          id: 'reasoning',
          name: 'Reasoning & Math',
          description: 'Models strong in logic, math, and problem solving',
          icon: '🧮',
          models: _reasoningModels,
        ),
        ModelCategory(
          id: 'multilingual',
          name: 'Multilingual',
          description: 'Models supporting multiple languages',
          icon: '🌍',
          models: _multilingualModels,
        ),
        ModelCategory(
          id: 'uncensored',
          name: 'Uncensored',
          description: 'Models with reduced content restrictions',
          icon: '🔓',
          models: _uncensoredModels,
        ),
        ModelCategory(
          id: 'tiny',
          name: 'Tiny Models',
          description: 'Very small models for low-end devices (<2GB RAM)',
          icon: '📱',
          models: _tinyModels,
        ),
        ModelCategory(
          id: 'roleplay',
          name: 'Roleplay & Chat',
          description: 'Models optimized for character roleplay',
          icon: '🎭',
          models: _roleplayModels,
        ),
      ];

  /// Get a specific category by ID
  static ModelCategory? getCategory(String id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get all models from all categories
  static List<CuratedModel> get allModels {
    return categories.expand((c) => c.models).toList();
  }

  /// Search curated models
  static List<CuratedModel> search(String query) {
    final lower = query.toLowerCase();
    return allModels.where((m) {
      return m.name.toLowerCase().contains(lower) ||
          m.modelId.toLowerCase().contains(lower) ||
          m.description.toLowerCase().contains(lower) ||
          m.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
  }

  /// Get models by size category
  static List<CuratedModel> getBySize(ModelSize size) {
    return allModels.where((m) => m.size == size).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CURATED MODEL LISTS
  // ═══════════════════════════════════════════════════════════════════════════

  static final List<CuratedModel> _generalModels = [
    CuratedModel(
      name: 'Llama 3.2 3B',
      modelId: 'bartowski/Llama-3.2-3B-Instruct-GGUF',
      description: 'Meta\'s latest small model, great balance of speed and quality',
      size: ModelSize.small,
      parameters: '3B',
      quantization: 'Q4_K_M',
      fileSize: '1.9 GB',
      tags: ['llama', 'meta', 'instruct'],
      recommended: true,
    ),
    CuratedModel(
      name: 'Mistral 7B',
      modelId: 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF',
      description: 'Popular 7B model with excellent performance',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.4 GB',
      tags: ['mistral', 'instruct'],
      recommended: true,
    ),
    CuratedModel(
      name: 'Phi-3 Mini',
      modelId: 'microsoft/Phi-3-mini-4k-instruct-gguf',
      description: 'Microsoft\'s efficient 3.8B model',
      size: ModelSize.small,
      parameters: '3.8B',
      quantization: 'Q4_K_M',
      fileSize: '2.2 GB',
      tags: ['microsoft', 'phi', 'efficient'],
    ),
    CuratedModel(
      name: 'Gemma 2 9B',
      modelId: 'bartowski/gemma-2-9b-it-GGUF',
      description: 'Google\'s Gemma 2 model, great for general tasks',
      size: ModelSize.medium,
      parameters: '9B',
      quantization: 'Q4_K_M',
      fileSize: '5.4 GB',
      tags: ['google', 'gemma'],
    ),
  ];

  static final List<CuratedModel> _codeModels = [
    CuratedModel(
      name: 'DeepSeek Coder 6.7B',
      modelId: 'TheBloke/deepseek-coder-6.7B-instruct-GGUF',
      description: 'Excellent for code generation and understanding',
      size: ModelSize.medium,
      parameters: '6.7B',
      quantization: 'Q4_K_M',
      fileSize: '4.0 GB',
      tags: ['code', 'deepseek'],
      recommended: true,
    ),
    CuratedModel(
      name: 'CodeLlama 7B',
      modelId: 'TheBloke/CodeLlama-7B-Instruct-GGUF',
      description: 'Meta\'s code-specialized model',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.0 GB',
      tags: ['code', 'meta', 'llama'],
    ),
    CuratedModel(
      name: 'StarCoder2 3B',
      modelId: 'bigcode/starcoder2-3b',
      description: 'Small but capable code model',
      size: ModelSize.small,
      parameters: '3B',
      quantization: 'Q4_K_M',
      fileSize: '1.8 GB',
      tags: ['code', 'bigcode'],
    ),
    CuratedModel(
      name: 'Qwen2.5 Coder 7B',
      modelId: 'Qwen/Qwen2.5-Coder-7B-Instruct-GGUF',
      description: 'Alibaba\'s latest code model',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.5 GB',
      tags: ['code', 'qwen', 'alibaba'],
    ),
  ];

  static final List<CuratedModel> _creativeModels = [
    CuratedModel(
      name: 'Noromaid 12B',
      modelId: 'NeverSleep/Noromaid-12B-GGUF',
      description: 'Optimized for creative writing and storytelling',
      size: ModelSize.large,
      parameters: '12B',
      quantization: 'Q4_K_M',
      fileSize: '7.0 GB',
      tags: ['creative', 'writing'],
    ),
    CuratedModel(
      name: 'MythoMax 13B',
      modelId: 'TheBloke/MythoMax-L2-13B-GGUF',
      description: 'Popular creative writing model',
      size: ModelSize.large,
      parameters: '13B',
      quantization: 'Q4_K_M',
      fileSize: '7.8 GB',
      tags: ['creative', 'writing', 'storytelling'],
      recommended: true,
    ),
  ];

  static final List<CuratedModel> _reasoningModels = [
    CuratedModel(
      name: 'OpenMath Mistral',
      modelId: 'nvidia/OpenMath-7B-v0.1-GGUF',
      description: 'Specialized for mathematical reasoning',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.2 GB',
      tags: ['math', 'reasoning'],
    ),
    CuratedModel(
      name: 'WizardMath 7B',
      modelId: 'TheBloke/WizardMath-7B-V1.1-GGUF',
      description: 'Strong mathematical problem solving',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.4 GB',
      tags: ['math', 'reasoning', 'wizard'],
      recommended: true,
    ),
  ];

  static final List<CuratedModel> _multilingualModels = [
    CuratedModel(
      name: 'BLOOM 3B',
      modelId: 'bigscience/bloom-3b',
      description: 'Supports 46 languages',
      size: ModelSize.small,
      parameters: '3B',
      quantization: 'Q4_K_M',
      fileSize: '1.8 GB',
      tags: ['multilingual', 'bloom'],
    ),
    CuratedModel(
      name: 'Qwen2 7B',
      modelId: 'Qwen/Qwen2-7B-Instruct-GGUF',
      description: 'Strong in Chinese and English',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.5 GB',
      tags: ['multilingual', 'chinese', 'english', 'qwen'],
      recommended: true,
    ),
    CuratedModel(
      name: 'SOLAR 10.7B',
      modelId: 'upstage/SOLAR-10.7B-Instruct-v1.0-GGUF',
      description: 'Korean-English bilingual model',
      size: ModelSize.large,
      parameters: '10.7B',
      quantization: 'Q4_K_M',
      fileSize: '6.5 GB',
      tags: ['multilingual', 'korean', 'english'],
    ),
  ];

  static final List<CuratedModel> _uncensoredModels = [
    CuratedModel(
      name: 'Dolphin Mistral',
      modelId: 'cognitivecomputations/dolphin-2.6-mistral-7b-GGUF',
      description: 'Uncensored model based on Mistral',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.4 GB',
      tags: ['uncensored', 'dolphin', 'mistral'],
      recommended: true,
      isUncensored: true,
    ),
    CuratedModel(
      name: 'WizardLM Uncensored',
      modelId: 'TheBloke/WizardLM-7B-uncensored-GGUF',
      description: 'Uncensored version of WizardLM',
      size: ModelSize.medium,
      parameters: '7B',
      quantization: 'Q4_K_M',
      fileSize: '4.0 GB',
      tags: ['uncensored', 'wizard'],
      isUncensored: true,
    ),
    CuratedModel(
      name: 'Luna AI Llama3',
      modelId: 'TheDrummer/Luna-AI-Llama3-8B-GGUF',
      description: 'Uncensored Llama 3 variant',
      size: ModelSize.medium,
      parameters: '8B',
      quantization: 'Q4_K_M',
      fileSize: '4.9 GB',
      tags: ['uncensored', 'llama3'],
      isUncensored: true,
    ),
    CuratedModel(
      name: 'Nous Hermes 2',
      modelId: 'NousResearch/Hermes-2-Pro-Llama-3-8B-GGUF',
      description: 'High quality uncensored model',
      size: ModelSize.medium,
      parameters: '8B',
      quantization: 'Q4_K_M',
      fileSize: '4.9 GB',
      tags: ['uncensored', 'nous', 'hermes'],
      isUncensored: true,
    ),
  ];

  static final List<CuratedModel> _tinyModels = [
    CuratedModel(
      name: 'TinyLlama 1.1B',
      modelId: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
      description: 'Very small, fast model for basic tasks',
      size: ModelSize.tiny,
      parameters: '1.1B',
      quantization: 'Q4_K_M',
      fileSize: '669 MB',
      tags: ['tiny', 'fast'],
      recommended: true,
    ),
    CuratedModel(
      name: 'Phi-2 2.7B',
      modelId: 'TheBloke/phi-2-GGUF',
      description: 'Microsoft\'s small but capable model',
      size: ModelSize.tiny,
      parameters: '2.7B',
      quantization: 'Q4_K_M',
      fileSize: '1.6 GB',
      tags: ['tiny', 'microsoft', 'phi'],
    ),
    CuratedModel(
      name: 'Qwen1.5 1.8B',
      modelId: 'Qwen/Qwen1.5-1.8B-Chat-GGUF',
      description: 'Small multilingual model',
      size: ModelSize.tiny,
      parameters: '1.8B',
      quantization: 'Q4_K_M',
      fileSize: '1.1 GB',
      tags: ['tiny', 'multilingual', 'qwen'],
    ),
    CuratedModel(
      name: 'SmolLM 1.7B',
      modelId: 'HuggingFaceTB/SmolLM-1.7B-Instruct-GGUF',
      description: 'HuggingFace\'s small instruct model',
      size: ModelSize.tiny,
      parameters: '1.7B',
      quantization: 'Q4_K_M',
      fileSize: '1.0 GB',
      tags: ['tiny', 'huggingface'],
    ),
  ];

  static final List<CuratedModel> _roleplayModels = [
    CuratedModel(
      name: 'Llama 3 8B Instruct',
      modelId: 'QuantFactory/Meta-Llama-3-8B-Instruct-GGUF',
      description: 'Meta\'s latest model, great for roleplay',
      size: ModelSize.medium,
      parameters: '8B',
      quantization: 'Q4_K_M',
      fileSize: '4.9 GB',
      tags: ['roleplay', 'llama3', 'meta'],
      recommended: true,
    ),
    CuratedModel(
      name: 'Psyfighter 13B',
      modelId: 'TheBloke/Psyfighter-13B-GGUF',
      description: 'Specialized for character roleplay',
      size: ModelSize.large,
      parameters: '13B',
      quantization: 'Q4_K_M',
      fileSize: '7.8 GB',
      tags: ['roleplay', 'character'],
    ),
  ];
}

/// Model size category
enum ModelSize {
  tiny,   // < 2GB
  small,  // 2-4GB
  medium, // 4-8GB
  large,  // 8GB+
}

extension ModelSizeExtension on ModelSize {
  String get label {
    switch (this) {
      case ModelSize.tiny:
        return 'Tiny (<2GB)';
      case ModelSize.small:
        return 'Small (2-4GB)';
      case ModelSize.medium:
        return 'Medium (4-8GB)';
      case ModelSize.large:
        return 'Large (8GB+)';
    }
  }

  String get icon {
    switch (this) {
      case ModelSize.tiny:
        return '🐜';
      case ModelSize.small:
        return '🐇';
      case ModelSize.medium:
        return '🐕';
      case ModelSize.large:
        return '🐘';
    }
  }
}

/// Curated model category
class ModelCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<CuratedModel> models;

  ModelCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.models,
  });
}

/// Curated model information
class CuratedModel {
  final String name;
  final String modelId;
  final String description;
  final ModelSize size;
  final String parameters;
  final String quantization;
  final String fileSize;
  final List<String> tags;
  final bool recommended;
  final bool isUncensored;

  CuratedModel({
    required this.name,
    required this.modelId,
    required this.description,
    required this.size,
    required this.parameters,
    required this.quantization,
    required this.fileSize,
    required this.tags,
    this.recommended = false,
    this.isUncensored = false,
  });

  /// Get the primary GGUF filename
  String get primaryFilename {
    // Most GGUF repos have files like: model.Q4_K_M.gguf
    return '$name.$quantization.gguf'.replaceAll(' ', '-').toLowerCase();
  }

  /// Get HuggingFace URL
  String get hfUrl => 'https://huggingface.co/$modelId';

  /// Get download URL
  String get downloadUrl => 'https://huggingface.co/$modelId/resolve/main/$primaryFilename';
}