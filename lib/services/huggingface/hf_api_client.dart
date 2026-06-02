import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Hugging Face API client for browsing and downloading models
class HuggingFaceApiClient {
  HuggingFaceApiClient._();
  static final HuggingFaceApiClient instance = HuggingFaceApiClient._();

  static const String _baseUrl = 'https://huggingface.co/api';
  static const String _modelBaseUrl = 'https://huggingface.co';

  /// Search for models on Hugging Face
  Future<List<HFModel>> searchModels({
    String? query,
    String? filter,
    String? task,
    String? library,
    String? language,
    List<String>? tags,
    int limit = 20,
    int offset = 0,
    String sort = 'downloads',
    String direction = '-1',
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'sort': sort,
      'direction': direction,
      'full': 'true',
    };

    if (query != null && query.isNotEmpty) {
      params['search'] = query;
    }
    if (filter != null && filter.isNotEmpty) {
      params['filter'] = filter;
    }
    if (task != null && task.isNotEmpty) {
      params['pipeline_tag'] = task;
    }
    if (library != null && library.isNotEmpty) {
      params['library'] = library;
    }
    if (tags != null && tags.isNotEmpty) {
      params['tags'] = tags.join(',');
    }

    final uri = Uri.parse('$_baseUrl/models').replace(queryParameters: params);

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HF API error: ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => HFModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search models: $e');
    }
  }

  /// Get detailed info about a specific model
  Future<HFModelInfo> getModelInfo(String modelId) async {
    final uri = Uri.parse('$_baseUrl/models/$modelId');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HF API error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HFModelInfo.fromJson(json);
    } catch (e) {
      throw Exception('Failed to get model info: $e');
    }
  }

  /// Get list of files in a model repository
  Future<List<HFModelFile>> listModelFiles(String modelId) async {
    final uri = Uri.parse('$_baseUrl/models/$modelId/tree/main');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HF API error: ${response.statusCode}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => HFModelFile.fromJson(json, modelId))
          .where((f) => f.isDownloadable)
          .toList();
    } catch (e) {
      throw Exception('Failed to list model files: $e');
    }
  }

  /// Get download URL for a specific file
  String getFileDownloadUrl(String modelId, String filename) {
    return '$_modelBaseUrl/$modelId/resolve/main/$filename';
  }

  /// Stream download a file with progress tracking
  Stream<HFDownloadProgress> downloadModel({
    required String modelId,
    required String filename,
    required String savePath,
    Map<String, String>? headers,
  }) async* {
    final url = getFileDownloadUrl(modelId, filename);

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));

      if (headers != null) {
        request.headers.addAll(headers);
      }

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? -1;
      var downloadedBytes = 0;

      final chunks = <int>[];

      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
        downloadedBytes += chunk.length;

        yield HFDownloadProgress(
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0,
          filename: filename,
          modelId: modelId,
        );
      }

      // Write to file would happen here in actual implementation
      // For now, we just track progress

      yield HFDownloadProgress(
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        filename: filename,
        modelId: modelId,
        completed: true,
      );

      client.close();
    } catch (e) {
      yield HFDownloadProgress(
        downloadedBytes: 0,
        totalBytes: 0,
        progress: 0,
        filename: filename,
        modelId: modelId,
        error: e.toString(),
      );
    }
  }

  /// Get trending/popular models
  Future<List<HFModel>> getTrendingModels({
    String? task,
    int limit = 10,
  }) async {
    return searchModels(
      task: task,
      limit: limit,
      sort: 'trending',
    );
  }

  /// Get models by task type
  Future<List<HFModel>> getModelsByTask(String task, {int limit = 20}) async {
    return searchModels(
      task: task,
      limit: limit,
    );
  }

  /// Get GGUF models (for llama.cpp)
  Future<List<HFModel>> getGGUFModels({String? query, int limit = 20}) async {
    return searchModels(
      query: query ?? 'gguf',
      filter: 'gguf',
      limit: limit,
    );
  }

  /// Get quantized models suitable for mobile
  Future<List<HFModel>> getMobileModels({int limit = 20}) async {
    return searchModels(
      tags: ['gguf', 'quantized'],
      limit: limit,
    );
  }

  /// Search for uncensored models
  Future<List<HFModel>> getUncensoredModels({String? query, int limit = 20}) async {
    return searchModels(
      query: query,
      tags: ['uncensored'],
      limit: limit,
    );
  }

  /// Get model categories/tags
  Future<List<HFTag>> getPopularTags() async {
    try {
      final uri = Uri.parse('$_baseUrl/models-tags-by-type');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return _getDefaultTags();
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tags = <HFTag>[];

      // Parse pipeline tags (tasks)
      final pipeline = data['pipeline_tag'] as List? ?? [];
      for (final t in pipeline) {
        if (t is Map) {
          tags.add(HFTag(
            id: t['id'] as String,
            label: t['label'] as String? ?? t['id'] as String,
            type: 'task',
          ));
        }
      }

      // Parse library tags
      final library = data['library'] as List? ?? [];
      for (final t in library) {
        if (t is Map) {
          tags.add(HFTag(
            id: t['id'] as String,
            label: t['label'] as String? ?? t['id'] as String,
            type: 'library',
          ));
        }
      }

      return tags;
    } catch (e) {
      return _getDefaultTags();
    }
  }

  List<HFTag> _getDefaultTags() {
    return [
      HFTag(id: 'text-generation', label: 'Text Generation', type: 'task'),
      HFTag(id: 'text-classification', label: 'Text Classification', type: 'task'),
      HFTag(id: 'question-answering', label: 'Question Answering', type: 'task'),
      HFTag(id: 'summarization', label: 'Summarization', type: 'task'),
      HFTag(id: 'translation', label: 'Translation', type: 'task'),
      HFTag(id: 'fill-mask', label: 'Fill Mask', type: 'task'),
      HFTag(id: 'text-to-image', label: 'Text to Image', type: 'task'),
      HFTag(id: 'image-classification', label: 'Image Classification', type: 'task'),
      HFTag(id: 'gguf', label: 'GGUF', type: 'format'),
      HFTag(id: 'onnx', label: 'ONNX', type: 'format'),
      HFTag(id: 'tflite', label: 'TensorFlow Lite', type: 'format'),
    ];
  }
}

/// Model listing result
class HFModel {
  final String id;
  final String modelId;
  final String author;
  final String name;
  final int downloads;
  final int likes;
  final List<String> tags;
  final String? pipelineTag;
  final DateTime? lastModified;
  final bool isPrivate;
  final Map<String, dynamic> raw;

  HFModel({
    required this.id,
    required this.modelId,
    required this.author,
    required this.name,
    required this.downloads,
    required this.likes,
    required this.tags,
    this.pipelineTag,
    this.lastModified,
    this.isPrivate = false,
    this.raw = const {},
  });

  factory HFModel.fromJson(Map<String, dynamic> json) {
    final modelId = json['modelId'] as String? ?? json['id'] as String? ?? '';
    final parts = modelId.split('/');
    final author = parts.length > 1 ? parts[0] : 'unknown';
    final name = parts.length > 1 ? parts.sublist(1).join('/') : modelId;

    return HFModel(
      id: json['id'] as String? ?? modelId,
      modelId: modelId,
      author: author,
      name: name,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      pipelineTag: json['pipeline_tag'] as String?,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String)
          : null,
      isPrivate: json['private'] as bool? ?? false,
      raw: json,
    );
  }

  bool get isGGUF => tags.any((t) => t.toLowerCase() == 'gguf');
  bool get isQuantized => tags.any((t) => t.toLowerCase().contains('quantized') || t.toLowerCase().startsWith('q'));

  String get displayName => name;
  String get fullId => modelId;

  String formatDownloads() {
    if (downloads >= 1000000) {
      return '${(downloads / 1000000).toStringAsFixed(1)}M';
    } else if (downloads >= 1000) {
      return '${(downloads / 1000).toStringAsFixed(1)}K';
    }
    return downloads.toString();
  }
}

/// Detailed model information
class HFModelInfo {
  final String modelId;
  final String author;
  final String description;
  final List<String> tags;
  final List<HFModelFile> files;
  final int downloads;
  final int likes;
  final String? cardData;
  final Map<String, dynamic> raw;

  HFModelInfo({
    required this.modelId,
    required this.author,
    required this.description,
    required this.tags,
    required this.files,
    required this.downloads,
    required this.likes,
    this.cardData,
    this.raw = const {},
  });

  factory HFModelInfo.fromJson(Map<String, dynamic> json) {
    final modelId = json['modelId'] as String? ?? json['id'] as String? ?? '';
    final parts = modelId.split('/');
    final author = parts.length > 1 ? parts[0] : 'unknown';

    final siblings = json['siblings'] as List? ?? [];
    final files = siblings
        .map((s) => HFModelFile(
              path: s['rfilename'] as String? ?? '',
              modelId: modelId,
              size: 0,
            ))
        .toList();

    return HFModelInfo(
      modelId: modelId,
      author: author,
      description: '',
      tags: List<String>.from(json['tags'] ?? []),
      files: files,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      cardData: json['cardData']?.toString(),
      raw: json,
    );
  }
}

/// Model file information
class HFModelFile {
  final String path;
  final String modelId;
  final int size;
  final String? lfs;

  HFModelFile({
    required this.path,
    required this.modelId,
    required this.size,
    this.lfs,
  });

  factory HFModelFile.fromJson(Map<String, dynamic> json, String modelId) {
    return HFModelFile(
      path: json['path'] as String? ?? '',
      modelId: modelId,
      size: json['size'] as int? ?? 0,
      lfs: json['lfs']?['oid'] as String?,
    );
  }

  bool get isDownloadable {
    final ext = path.split('.').last.toLowerCase();
    return ['gguf', 'bin', 'onnx', 'tflite', 'safetensors'].contains(ext) ||
        path.endsWith('.gguf') ||
        path.endsWith('.bin');
  }

  String get filename => path.split('/').last;

  String get format {
    final ext = filename.split('.').last.toLowerCase();
    return ext;
  }

  String formatSize() {
    if (size <= 0) return 'Unknown';
    if (size >= 1073741824) {
      return '${(size / 1073741824).toStringAsFixed(2)} GB';
    } else if (size >= 1048576) {
      return '${(size / 1048576).toStringAsFixed(2)} MB';
    } else if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    }
    return '$size B';
  }
}

/// Download progress tracking
class HFDownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final String filename;
  final String modelId;
  final bool completed;
  final String? error;

  HFDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.filename,
    required this.modelId,
    this.completed = false,
    this.error,
  });

  String formatProgress() {
    if (totalBytes <= 0) {
      return '${_formatBytes(downloadedBytes)} downloaded';
    }
    return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)} (${(progress * 100).toStringAsFixed(1)}%)';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
  }
}

/// HF Tag/Category
class HFTag {
  final String id;
  final String label;
  final String type; // 'task', 'library', 'format'

  HFTag({
    required this.id,
    required this.label,
    required this.type,
  });
}