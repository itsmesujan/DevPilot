import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/rag/document_ingester.dart';
import '../../services/rag/rag_service.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

final documentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return RagService.instance.getAllDocuments();
});

final ragEnabledProvider = StateProvider<bool>((ref) => true);

// ── Screen ─────────────────────────────────────────────────────────────────────

class KnowledgeBaseScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  ConsumerState<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends ConsumerState<KnowledgeBaseScreen> {
  bool _isIngesting = false;
  double _ingestProgress = 0;
  String _ingestStatus = '';

  // ── Ingestion Actions ───────────────────────────────────────────────────────

  Future<void> _pickAndIngestFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'dart', 'py', 'js', 'ts', 'json', 'yaml', 'csv'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      await _ingest(
        label: file.name,
        action: () => DocumentIngester.instance.ingestFile(file.path!,
            onProgress: (p) => setState(() => _ingestProgress = p)),
      );
    }
  }

  Future<void> _ingestFromUrl() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Add URL', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Ingest'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    await _ingest(
      label: url,
      action: () => DocumentIngester.instance.ingestUrl(url,
          onProgress: (p) => setState(() => _ingestProgress = p)),
    );
  }

  Future<void> _ingestPastedText() async {
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Paste Text', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Paste your text here...',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ingest')),
        ],
      ),
    );
    if (result != true || textCtrl.text.trim().isEmpty) return;
    final title = titleCtrl.text.trim().isEmpty ? 'Pasted text' : titleCtrl.text.trim();
    await _ingest(
      label: title,
      action: () => DocumentIngester.instance.ingestText(textCtrl.text,
          title: title, onProgress: (p) => setState(() => _ingestProgress = p)),
    );
  }

  Future<void> _ingest({
    required String label,
    required Future<IngestResult> Function() action,
  }) async {
    setState(() {
      _isIngesting = true;
      _ingestProgress = 0;
      _ingestStatus = 'Ingesting $label...';
    });

    try {
      final result = await action();
      if (!mounted) return;
      if (result.success) {
        ref.invalidate(documentsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Text('✅ ${result.sourceName} indexed (${result.chunkCount} chunks)'),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text('❌ ${result.error}'),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade800,
        content: Text('Error: $e'),
      ));
    } finally {
      if (mounted) setState(() { _isIngesting = false; _ingestStatus = ''; });
    }
  }

  void _deleteDocument(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Delete Document', style: TextStyle(color: Colors.white)),
        content: Text('Remove "$name" from the knowledge base?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    RagService.instance.deleteDocument(id);
    ref.invalidate(documentsProvider);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final ragEnabled = ref.watch(ragEnabledProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Knowledge Base', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // RAG toggle
          Row(children: [
            const Text('RAG', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(width: 4),
            Switch(
              value: ragEnabled,
              onChanged: (v) {
                ref.read(ragEnabledProvider.notifier).state = v;
                RagService.instance.enabled = v;
              },
              activeTrackColor: const Color(0xFF7C3AED),
            ),
          ]),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Stats bar
        _StatsBar(),
        const Divider(color: Colors.white12, height: 1),

        // Ingestion progress
        if (_isIngesting) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_ingestStatus, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _ingestProgress,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFF7C3AED),
                  minHeight: 6,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        // Documents list
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            data: (docs) => docs.isEmpty
                ? _EmptyState(onAdd: _pickAndIngestFile)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      return _DocumentTile(
                        doc: doc,
                        onDelete: () => _deleteDocument(doc['id'] as String, doc['name'] as String),
                      ).animate().fadeIn(delay: Duration(milliseconds: i * 50));
                    },
                  ),
          ),
        ),
      ]),

      // Add FAB with speed dial
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'url',
            backgroundColor: const Color(0xFF1E3A5F),
            onPressed: _isIngesting ? null : _ingestFromUrl,
            tooltip: 'Add URL',
            child: const Icon(Icons.link, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'text',
            backgroundColor: const Color(0xFF1E3A5F),
            onPressed: _isIngesting ? null : _ingestPastedText,
            tooltip: 'Paste text',
            child: const Icon(Icons.text_fields, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'file',
            backgroundColor: const Color(0xFF7C3AED),
            onPressed: _isIngesting ? null : _pickAndIngestFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Add File'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chunkCount = RagService.instance.chunkCount;
    final docCount = RagService.instance.documentCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF12122A),
      child: Row(children: [
        _Stat(label: 'Documents', value: '$docCount', icon: Icons.description),
        const SizedBox(width: 24),
        _Stat(label: 'Chunks', value: '$chunkCount', icon: Icons.layers),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade900.withAlpha(128),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade700, width: 0.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bolt, color: Colors.green.shade400, size: 14),
            const SizedBox(width: 4),
            Text('RAG Active', style: TextStyle(color: Colors.green.shade400, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: Colors.white38),
    const SizedBox(width: 6),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ]),
  ]);
}

class _DocumentTile extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDelete;
  const _DocumentTile({required this.doc, required this.onDelete});

  IconData _typeIcon(String type) => switch (type) {
    'pdf' => Icons.picture_as_pdf,
    'url' => Icons.language,
    'text' => Icons.article,
    _ => Icons.code,
  };

  Color _typeColor(String type) => switch (type) {
    'pdf' => Colors.red.shade400,
    'url' => Colors.blue.shade400,
    'text' => Colors.teal.shade400,
    _ => Colors.orange.shade400,
  };

  @override
  Widget build(BuildContext context) {
    final type = doc['type'] as String? ?? 'text';
    final name = doc['name'] as String? ?? 'Unknown';
    final chunks = doc['chunk_count'] as int? ?? 0;
    final indexedAt = doc['indexed_at'] as String? ?? '';
    final date = indexedAt.length > 10 ? indexedAt.substring(0, 10) : indexedAt;

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withAlpha(15)),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _typeColor(type).withAlpha(38),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_typeIcon(type), color: _typeColor(type), size: 20),
        ),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text('$chunks chunks • $date',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white24),
          onPressed: onDelete,
        ),
        dense: true,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.auto_stories_outlined, size: 72, color: Colors.white.withAlpha(20)),
      const SizedBox(height: 16),
      const Text('No documents yet',
          style: TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text(
        'Add PDFs, text files, or URLs to give your AI\nassistant access to your private knowledge.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white30, fontSize: 13),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
        icon: const Icon(Icons.upload_file),
        label: const Text('Add Document'),
        onPressed: onAdd,
      ),
    ]).animate().fadeIn(duration: 500.ms),
  );
}
