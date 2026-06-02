import 'package:uuid/uuid.dart';

class MemoryItem {
  final String id;
  final String content;
  final String type; // episodic | semantic | profile
  final String? sessionId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  double? similarityScore;

  MemoryItem({
    String? id,
    required this.content,
    required this.type,
    this.sessionId,
    this.metadata = const {},
    DateTime? createdAt,
    this.similarityScore,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

class ResearchReport {
  final String id;
  final String query;
  final List<ResearchSource> sources;
  final String synthesis;
  final DateTime createdAt;

  ResearchReport({
    String? id,
    required this.query,
    this.sources = const [],
    required this.synthesis,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

class ResearchSource {
  final String url;
  final String title;
  final String summary;
  final double relevance;

  const ResearchSource({
    required this.url,
    required this.title,
    required this.summary,
    required this.relevance,
  });
}
