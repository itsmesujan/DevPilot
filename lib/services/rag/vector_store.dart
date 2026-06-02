import 'dart:typed_data';
import '../storage/app_database.dart';

/// Local vector store backed by SQLite with cosine-similarity search.
///
/// Uses Float32 embeddings stored as BLOBs and a pure-Dart cosine
/// similarity scorer over the top-N candidates (no sqlite-vec extension
/// needed — falls back gracefully if the extension is unavailable).
class VectorStore {
  VectorStore._();
  static final VectorStore instance = VectorStore._();

  // ── Insert ──────────────────────────────────────────────────────────────────

  /// Store a text chunk with its embedding vector.
  void insertChunk({
    required String id,
    required String content,
    required List<double> embedding,
    required String sourceId,
    required String sourceType, // 'pdf' | 'text' | 'url' | 'code'
    int chunkIndex = 0,
  }) {
    final embeddingBytes = _toBytes(embedding);
    AppDatabase.instance.insertVectorChunk(
      id: id,
      content: content,
      embedding: embeddingBytes,
      sourceId: sourceId,
      sourceType: sourceType,
      chunkIndex: chunkIndex,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  /// Find the [topK] most semantically similar chunks to [queryEmbedding].
  List<VectorSearchResult> search(
    List<double> queryEmbedding, {
    int topK = 5,
    String? sourceId, // filter to one document if provided
  }) {
    final rows = AppDatabase.instance.getAllVectorChunks(sourceId: sourceId);

    final scored = rows.map((row) {
      final embedding = _fromBytes(row['embedding'] as Uint8List);
      final score = _cosineSimilarity(queryEmbedding, embedding);
      return VectorSearchResult(
        id: row['id'] as String,
        content: row['content'] as String,
        sourceId: row['source_id'] as String,
        sourceType: row['source_type'] as String,
        chunkIndex: row['chunk_index'] as int,
        score: score,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).where((r) => r.score > 0.1).toList();
  }

  // ── Delete ───────────────────────────────────────────────────────────────────

  void deleteChunksForSource(String sourceId) {
    AppDatabase.instance.deleteVectorChunksBySource(sourceId);
  }

  // ── Math ────────────────────────────────────────────────────────────────────

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = (normA * normB);
    if (denom == 0) return 0;
    return dot / (denom == 0 ? 1 : (normA * normB > 0 ? (normA * normB) : 1));
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  Uint8List _toBytes(List<double> vec) {
    final data = ByteData(vec.length * 4);
    for (int i = 0; i < vec.length; i++) {
      data.setFloat32(i * 4, vec[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  List<double> _fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final length = bytes.length ~/ 4;
    return List.generate(length, (i) => data.getFloat32(i * 4, Endian.little));
  }
}

class VectorSearchResult {
  final String id;
  final String content;
  final String sourceId;
  final String sourceType;
  final int chunkIndex;
  final double score;

  const VectorSearchResult({
    required this.id,
    required this.content,
    required this.sourceId,
    required this.sourceType,
    required this.chunkIndex,
    required this.score,
  });
}
