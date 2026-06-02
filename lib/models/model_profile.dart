enum ModelBackend { local, cloud }

enum ModelCapability {
  chat,
  vision,
  voice,
  imageGeneration,
  embedding,
  code,
}

enum DeviceTier { ultra, high, mid, low }

/// Visual tag labels shown as colored badges on model cards.
enum ModelTag {
  newModel,      // 🆕 Latest / just released
  popular,       // 🔥 Community favorite
  fast,          // ⚡ Speed optimized
  powerful,      // 💪 High capability
  uncensored,    // 🔓 No content restrictions
  reasoning,     // 🧠 Chain-of-thought / thinking
  multilingual,  // 🌍 Many languages
  tiny,          // 🪶 Ultra-small / low RAM
  vision,        // 👁️ Supports image input
  roleplay,      // 🎭 Good for creative/roleplay
  coding,        // 💻 Code specialist
  image,         // 🎨 Image generation
  audio,         // 🎤 Speech / audio
  embedding,     // 📊 Vector embeddings
}

class ModelProfile {
  final String id;
  final String name;
  final String description;
  final ModelBackend backend;
  final String provider; // openai, anthropic, gemini, mistral, deepseek, groq, meta, google, local…
  final List<ModelCapability> capabilities;
  final List<ModelTag> tags;
  final String? ggufFilename;
  final String? downloadUrl;
  final int? fileSizeMb;
  final int? minRamMb;
  final String? apiModelId;
  final bool isDownloaded;
  final double? contextLength;

  const ModelProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.backend,
    required this.provider,
    this.capabilities = const [ModelCapability.chat],
    this.tags = const [],
    this.ggufFilename,
    this.downloadUrl,
    this.fileSizeMb,
    this.minRamMb,
    this.apiModelId,
    this.isDownloaded = false,
    this.contextLength,
  });

  ModelProfile copyWith({bool? isDownloaded}) => ModelProfile(
        id: id,
        name: name,
        description: description,
        backend: backend,
        provider: provider,
        capabilities: capabilities,
        tags: tags,
        ggufFilename: ggufFilename,
        downloadUrl: downloadUrl,
        fileSizeMb: fileSizeMb,
        minRamMb: minRamMb,
        apiModelId: apiModelId,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        contextLength: contextLength,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'backend': backend.name,
        'provider': provider,
        'capabilities': capabilities.map((c) => c.name).toList(),
        'tags': tags.map((t) => t.name).toList(),
        'ggufFilename': ggufFilename,
        'downloadUrl': downloadUrl,
        'fileSizeMb': fileSizeMb,
        'minRamMb': minRamMb,
        'apiModelId': apiModelId,
        'isDownloaded': isDownloaded,
        'contextLength': contextLength,
      };

  factory ModelProfile.fromJson(Map<String, dynamic> json) {
    return ModelProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      backend: ModelBackend.values.byName(json['backend'] as String),
      provider: json['provider'] as String,
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => ModelCapability.values.byName(e as String))
              .toList() ??
          const [ModelCapability.chat],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) {
                try {
                  return ModelTag.values.byName(e as String);
                } catch (_) {
                  return null;
                }
              })
              .whereType<ModelTag>()
              .toList() ??
          const [],
      ggufFilename: json['ggufFilename'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      fileSizeMb: json['fileSizeMb'] as int?,
      minRamMb: json['minRamMb'] as int?,
      apiModelId: json['apiModelId'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      contextLength: (json['contextLength'] as num?)?.toDouble(),
    );
  }
}
