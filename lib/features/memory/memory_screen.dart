import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/memory_models.dart';
import '../../services/memory/memory_service.dart';
import '../../services/storage/app_database.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

enum MemoryFilter { all, episodic, semantic, profile }

final memoryFilterProvider =
    StateProvider<MemoryFilter>((ref) => MemoryFilter.all);

final memoryItemsProvider =
    FutureProvider.family<List<MemoryItem>, MemoryFilter>((ref, filter) async {
  final type = filter == MemoryFilter.all ? null : filter.name;
  return MemoryService.instance.getAll(type: type);
});

final memorySearchQueryProvider = StateProvider<String>((ref) => '');
final memorySearchResultsProvider =
    FutureProvider.family<List<MemoryItem>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return MemoryService.instance.search(query);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _deleteMemory(String id) {
    AppDatabase.instance.deleteMemory(id);
    // Invalidate providers to refresh list
    ref.invalidate(memoryItemsProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Memory deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(memoryFilterProvider);
    final searchQuery = ref.watch(memorySearchQueryProvider);
    final isSearching = searchQuery.isNotEmpty;

    final itemsAsync = isSearching
        ? ref.watch(memorySearchResultsProvider(searchQuery))
        : ref.watch(memoryItemsProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search memories…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(memorySearchQueryProvider.notifier)
                              .state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (v) =>
                  ref.read(memorySearchQueryProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips (hidden during search)
          if (!isSearching)
            SizedBox(
              height: 36,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: MemoryFilter.values
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f.name),
                            selected: filter == f,
                            onSelected: (_) => ref
                                .read(memoryFilterProvider.notifier)
                                .state = f,
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 8),

          // Memory list
          Expanded(
            child: itemsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error: $e')),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.memory_outlined,
                              size: 56, color: Colors.white12),
                          const SizedBox(height: 12),
                          Text(
                            isSearching
                                ? 'No memories matching "$searchQuery"'
                                : 'No ${filter == MemoryFilter.all ? '' : '${filter.name} '}memories yet.\nThey\'re created automatically as you chat.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _MemoryTile(
                        item: items[i],
                        onDelete: () => _deleteMemory(items[i].id),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MemoryTile extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback onDelete;
  const _MemoryTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _typeIcon(item.type, theme),
        title: Text(
          item.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          '${item.type} • ${_timeAgo(item.createdAt)}${item.similarityScore != null ? ' • score: ${item.similarityScore!.toStringAsFixed(2)}' : ''}',
          style:
              const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white24),
          onPressed: onDelete,
        ),
        dense: true,
      ),
    );
  }

  Widget _typeIcon(String type, ThemeData theme) {
    final (icon, color) = switch (type) {
      'episodic' => (Icons.history, theme.colorScheme.primary),
      'semantic' => (Icons.psychology, theme.colorScheme.secondary),
      'profile' => (Icons.person_outline, Colors.orange),
      _ => (Icons.notes, Colors.white38),
    };
    return Icon(icon, color: color, size: 20);
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
