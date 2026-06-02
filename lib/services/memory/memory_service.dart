import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../storage/app_database.dart';
import '../../models/memory_models.dart';

/// Simple semantic memory using keyword-based similarity scoring.
/// On devices with sqlite-vec support this can be swapped for real embeddings.
class MemoryService {
  MemoryService._();
  static final MemoryService instance = MemoryService._();

  // ── Store ─────────────────────────────────────────────────────────────────
  Future<void> storeEpisodic({
    required String content,
    String? sessionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    AppDatabase.instance.insertMemory(
      id: const Uuid().v4(),
      content: content,
      type: 'episodic',
      sessionId: sessionId,
      metadata: jsonEncode(metadata),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> storeSemantic({
    required String content,
    Map<String, dynamic> metadata = const {},
  }) async {
    AppDatabase.instance.insertMemory(
      id: const Uuid().v4(),
      content: content,
      type: 'semantic',
      metadata: jsonEncode(metadata),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> storeUserProfile({
    required String key,
    required String value,
  }) async {
    AppDatabase.instance.insertMemory(
      id: 'profile_$key',
      content: '$key: $value',
      type: 'profile',
      metadata: jsonEncode({'key': key}),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────
  Future<List<MemoryItem>> search(String query, {String? type, int topK = 5}) async {
    final allRows = AppDatabase.instance.getMemories(type: type, limit: 200);
    final scored = allRows.map((r) {
      final item = MemoryItem(
        id: r['id'] as String,
        content: r['content'] as String,
        type: r['type'] as String,
        sessionId: r['session_id'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
      item.similarityScore = _keywordSimilarity(query, item.content);
      return item;
    }).toList();

    scored.sort((a, b) => (b.similarityScore ?? 0).compareTo(a.similarityScore ?? 0));
    return scored.take(topK).where((m) => (m.similarityScore ?? 0) > 0).toList();
  }

  Future<List<MemoryItem>> getAll({String? type}) async {
    final rows = AppDatabase.instance.getMemories(type: type, limit: 100);
    return rows.map((r) => MemoryItem(
          id: r['id'] as String,
          content: r['content'] as String,
          type: r['type'] as String,
          sessionId: r['session_id'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
        )).toList();
  }

  Future<void> delete(String id) async {
    AppDatabase.instance.deleteMemory(id);
  }

  // ── Summarize and compress ────────────────────────────────────────────────
  Future<String> buildContextFromMemory(String query) async {
    final items = await search(query, topK: 5);
    if (items.isEmpty) return '';
    final sb = StringBuffer('Relevant memories:\n');
    for (final m in items) {
      sb.writeln('- [${m.type}] ${m.content}');
    }
    return sb.toString();
  }

  // ── Simple keyword similarity (TF-IDF approximation) ─────────────────────
  double _keywordSimilarity(String query, String doc) {
    final qWords = query.toLowerCase().split(RegExp(r'\W+')).toSet();
    final dWords = doc.toLowerCase().split(RegExp(r'\W+'));
    if (qWords.isEmpty || dWords.isEmpty) return 0;
    int matches = 0;
    for (final w in dWords) {
      if (qWords.contains(w) && w.length > 2) matches++;
    }
    return matches / dWords.length;
  }
}
