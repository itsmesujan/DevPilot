import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../storage/app_database.dart';
import 'vector_store.dart';

/// Core RAG (Retrieval-Augmented Generation) service.
///
/// Provides:
/// - Text embedding (pure-Dart TF-IDF fallback, upgradeable to MiniLM)
/// - Context retrieval: given a query, returns top-K relevant chunks
/// - Prompt context builder: formats retrieved chunks for injection
/// - Document management
class RagService {
  RagService._();
  static final RagService instance = RagService._();

  bool _enabled = true;
  bool get isEnabled => _enabled;
  set enabled(bool v) => _enabled = v;

  // Vocabulary size for TF-IDF embedding
  final int _vocabSize = 384;

  // ── Embedding ──────────────────────────────────────────────────────────────

  /// Compute a 384-dimensional embedding for [text].
  ///
  /// Uses a reproducible hash-based TF-IDF projection so that semantically
  /// similar texts produce similar vectors without requiring a loaded model.
  /// When a real MiniLM/Nomic model is available, this is replaced via
  /// [overrideEmbedFunction].
  List<double> Function(String)? _embeddingOverride;

  void overrideEmbedFunction(List<double> Function(String text) fn) {
    _embeddingOverride = fn;
  }

  List<double> computeEmbedding(String text) {
    if (_embeddingOverride != null) return _embeddingOverride!(text);
    return _tfidfEmbedding(text);
  }

  List<double> _tfidfEmbedding(String text) {
    final tokens = _tokenize(text);
    final vec = List.filled(_vocabSize, 0.0);

    final termFreq = <String, int>{};
    for (final t in tokens) {
      termFreq[t] = (termFreq[t] ?? 0) + 1;
    }

    for (final entry in termFreq.entries) {
      final term = entry.key;
      final tf = entry.value / tokens.length;
      // Reproducible hash into vector dimension
      final dim = term.codeUnits.fold(0, (acc, c) => (acc * 31 + c)) % _vocabSize;
      final positiveDim = dim.abs() % _vocabSize;
      vec[positiveDim] += tf;
    }

    // L2 normalize
    final norm = sqrt(vec.fold(0.0, (s, v) => s + v * v));
    if (norm > 0) {
      for (int i = 0; i < vec.length; i++) {
        vec[i] /= norm;
      }
    }
    return vec;
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toList();
  }

  // ── Serialization helpers (used by DocumentIngester) ──────────────────────

  static Uint8List embeddingToBytes(List<double> vec) {
    final data = ByteData(vec.length * 4);
    for (int i = 0; i < vec.length; i++) {
      data.setFloat32(i * 4, vec[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static List<double> bytesToEmbedding(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return List.generate(bytes.length ~/ 4, (i) => data.getFloat32(i * 4, Endian.little));
  }

  // ── Retrieval ──────────────────────────────────────────────────────────────

  /// Retrieve the top-K most relevant chunks for [query].
  Future<List<VectorSearchResult>> retrieve(
    String query, {
    int topK = 5,
    String? sourceId,
  }) async {
    if (!_enabled) return [];
    final queryVec = computeEmbedding(query);
    return VectorStore.instance.search(queryVec, topK: topK, sourceId: sourceId);
  }

  // ── Context Builder ────────────────────────────────────────────────────────

  /// Build a formatted context string ready for injection into a prompt.
  ///
  /// Returns empty string if RAG is disabled or no relevant results found.
  Future<String> buildContext(String query, {int topK = 5}) async {
    final results = await retrieve(query, topK: topK);
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('## Relevant Knowledge (from your documents)');
    buffer.writeln();

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      buffer.writeln('### Source ${i + 1} [${r.sourceType}] (relevance: ${(r.score * 100).toStringAsFixed(0)}%)');
      buffer.writeln(r.content);
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('Use the above knowledge when relevant. If unsure, say so.');
    return buffer.toString();
  }

  // ── Document Management ────────────────────────────────────────────────────

  List<Map<String, dynamic>> getAllDocuments() {
    return AppDatabase.instance.getAllDocuments();
  }

  void deleteDocument(String sourceId) {
    VectorStore.instance.deleteChunksForSource(sourceId);
    AppDatabase.instance.deleteDocument(sourceId);
  }

  int get documentCount => AppDatabase.instance.getAllDocuments().length;
  int get chunkCount => AppDatabase.instance.getVectorChunkCount();
}
