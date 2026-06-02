import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  late Database _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'devpilot.db');
    _db = sqlite3.open(dbPath);
    _createTables();
  }

  void _createTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        model_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS memory_items (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        session_id TEXT,
        metadata TEXT DEFAULT '{}',
        created_at TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS model_downloads (
        model_id TEXT PRIMARY KEY,
        filename TEXT NOT NULL,
        path TEXT NOT NULL,
        size_mb INTEGER,
        downloaded_at TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS agent_tasks (
        id TEXT PRIMARY KEY,
        goal TEXT NOT NULL,
        status TEXT NOT NULL,
        steps TEXT DEFAULT '[]',
        final_answer TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS workflows (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        nodes TEXT DEFAULT '[]',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_run_at TEXT
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS research_reports (
        id TEXT PRIMARY KEY,
        query TEXT NOT NULL,
        sources TEXT DEFAULT '[]',
        synthesis TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // ── RAG: Vector chunks ────────────────────────────────────────────────────
    _db.execute('''
      CREATE TABLE IF NOT EXISTS vector_chunks (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        embedding BLOB NOT NULL,
        source_id TEXT NOT NULL,
        source_type TEXT NOT NULL,
        chunk_index INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // ── RAG: Document registry ────────────────────────────────────────────────
    _db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        chunk_count INTEGER NOT NULL DEFAULT 0,
        indexed_at TEXT NOT NULL
      )
    ''');

    _db.execute('CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id)');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_memory_type ON memory_items(type)');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_vector_source ON vector_chunks(source_id)');
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  void insertMessage({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    String? modelId,
    required String createdAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO messages VALUES (?,?,?,?,?,?)',
      [id, sessionId, role, content, modelId, createdAt],
    );
  }

  List<Map<String, dynamic>> getMessages(String sessionId) {
    final rows = _db.select(
      'SELECT * FROM messages WHERE session_id = ? ORDER BY created_at ASC',
      [sessionId],
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  List<Map<String, dynamic>> searchMessages(String query, {int limit = 50}) {
    final rows = _db.select(
      'SELECT * FROM messages WHERE content LIKE ? ORDER BY created_at DESC LIMIT ?',
      ['%$query%', limit],
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  void deleteSession(String sessionId) {
    _db.execute('DELETE FROM messages WHERE session_id = ?', [sessionId]);
    _db.execute('DELETE FROM sessions WHERE id = ?', [sessionId]);
  }

  // ── Sessions ──────────────────────────────────────────────────────────────
  void upsertSession(String id, String title) {
    final now = DateTime.now().toIso8601String();
    _db.execute(
      'INSERT OR REPLACE INTO sessions (id, title, created_at, updated_at) VALUES (?,?,?,?)',
      [id, title, now, now],
    );
  }

  void updateSessionTime(String id) {
    _db.execute(
      'UPDATE sessions SET updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  List<Map<String, dynamic>> getSessions() {
    return _db
        .select('SELECT * FROM sessions ORDER BY updated_at DESC')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  // ── Memory ────────────────────────────────────────────────────────────────
  void insertMemory({
    required String id,
    required String content,
    required String type,
    String? sessionId,
    String metadata = '{}',
    required String createdAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO memory_items VALUES (?,?,?,?,?,?)',
      [id, content, type, sessionId, metadata, createdAt],
    );
  }

  List<Map<String, dynamic>> getMemories({String? type, int limit = 50}) {
    if (type != null) {
      return _db
          .select(
            'SELECT * FROM memory_items WHERE type = ? ORDER BY created_at DESC LIMIT ?',
            [type, limit],
          )
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    return _db
        .select(
          'SELECT * FROM memory_items ORDER BY created_at DESC LIMIT ?',
          [limit],
        )
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  void deleteMemory(String id) {
    _db.execute('DELETE FROM memory_items WHERE id = ?', [id]);
  }

  // ── Downloads ─────────────────────────────────────────────────────────────
  void upsertDownload({
    required String modelId,
    required String filename,
    required String path,
    required int sizeMb,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO model_downloads VALUES (?,?,?,?,?)',
      [modelId, filename, path, sizeMb, DateTime.now().toIso8601String()],
    );
  }

  bool isDownloaded(String modelId) {
    final rows = _db.select(
      'SELECT 1 FROM model_downloads WHERE model_id = ?',
      [modelId],
    );
    return rows.isNotEmpty;
  }

  String? getDownloadPath(String modelId) {
    final rows = _db.select(
      'SELECT path FROM model_downloads WHERE model_id = ?',
      [modelId],
    );
    if (rows.isEmpty) return null;
    return rows.first['path'] as String?;
  }

  List<Map<String, dynamic>> getAllDownloads() {
    return _db
        .select('SELECT * FROM model_downloads')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  void deleteDownload(String modelId) {
    _db.execute('DELETE FROM model_downloads WHERE model_id = ?', [modelId]);
  }

  // ── Agent tasks ───────────────────────────────────────────────────────────
  void upsertAgentTask({
    required String id,
    required String goal,
    required String status,
    required String steps,
    String? finalAnswer,
    required String createdAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO agent_tasks VALUES (?,?,?,?,?,?)',
      [id, goal, status, steps, finalAnswer, createdAt],
    );
  }

  List<Map<String, dynamic>> getAgentTasks() {
    return _db
        .select('SELECT * FROM agent_tasks ORDER BY created_at DESC')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  // ── Research reports ──────────────────────────────────────────────────────
  void insertReport({
    required String id,
    required String query,
    required String sources,
    required String synthesis,
    required String createdAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO research_reports VALUES (?,?,?,?,?)',
      [id, query, sources, synthesis, createdAt],
    );
  }

  List<Map<String, dynamic>> getReports() {
    return _db
        .select('SELECT * FROM research_reports ORDER BY created_at DESC')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  void close() => _db.dispose();

  // ── Workflows ─────────────────────────────────────────────────────────────
  void insertWorkflow({
    required String id,
    required String name,
    required String description,
    required String nodes,
    required String status,
    required String createdAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO workflows VALUES (?,?,?,?,?,?,null)',
      [id, name, description, nodes, status, createdAt],
    );
  }

  List<Map<String, dynamic>> getWorkflows() {
    return _db
        .select('SELECT * FROM workflows ORDER BY created_at DESC')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  void deleteWorkflow(String id) {
    _db.execute('DELETE FROM workflows WHERE id = ?', [id]);
  }

  // ── Convenience aliases ───────────────────────────────────────────────────
  void insertDownloadedModel({
    required String modelId,
    required String filename,
    required String path,
    required int sizeMb,
    required String downloadedAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO model_downloads VALUES (?,?,?,?,?)',
      [modelId, filename, path, sizeMb, downloadedAt],
    );
  }

  List<Map<String, dynamic>> getDownloadedModels() => getAllDownloads();

  void insertAgentTask({
    required String id,
    required String goal,
    required String status,
    required String createdAt,
  }) {
    upsertAgentTask(
        id: id,
        goal: goal,
        status: status,
        steps: '[]',
        createdAt: createdAt);
  }

  void updateAgentTaskStatus({required String id, required String status}) {
    _db.execute('UPDATE agent_tasks SET status = ? WHERE id = ?', [status, id]);
  }

  List<Map<String, dynamic>> getAgentTasksList({int limit = 20}) {
    return _db
        .select('SELECT * FROM agent_tasks ORDER BY created_at DESC LIMIT ?', [limit])
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  // ── RAG: Vector Chunks ────────────────────────────────────────────────────
  void insertVectorChunk({
    required String id,
    required String content,
    required dynamic embedding, // Uint8List
    required String sourceId,
    required String sourceType,
    required int chunkIndex,
    required String createdAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO vector_chunks VALUES (?,?,?,?,?,?,?)',
      [id, content, embedding, sourceId, sourceType, chunkIndex, createdAt],
    );
  }

  List<Map<String, dynamic>> getAllVectorChunks({String? sourceId}) {
    if (sourceId != null) {
      return _db
          .select('SELECT * FROM vector_chunks WHERE source_id = ?', [sourceId])
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    return _db
        .select('SELECT * FROM vector_chunks')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  void deleteVectorChunksBySource(String sourceId) {
    _db.execute('DELETE FROM vector_chunks WHERE source_id = ?', [sourceId]);
  }

  int getVectorChunkCount() {
    final result = _db.select('SELECT COUNT(*) as cnt FROM vector_chunks');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── RAG: Documents ─────────────────────────────────────────────────────────
  void insertDocument({
    required String id,
    required String name,
    required String type,
    required int chunkCount,
    required String indexedAt,
  }) {
    _db.execute(
      'INSERT OR REPLACE INTO documents VALUES (?,?,?,?,?)',
      [id, name, type, chunkCount, indexedAt],
    );
  }

  List<Map<String, dynamic>> getAllDocuments() {
    return _db
        .select('SELECT * FROM documents ORDER BY indexed_at DESC')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  void deleteDocument(String id) {
    _db.execute('DELETE FROM documents WHERE id = ?', [id]);
  }
}
