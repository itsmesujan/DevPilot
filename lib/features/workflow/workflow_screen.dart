import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/workflow_models.dart';
import '../../services/storage/app_database.dart';
import '../../services/workflow/workflow_executor.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final workflowsProvider =
    StateNotifierProvider<WorkflowsNotifier, List<Workflow>>((ref) {
  return WorkflowsNotifier();
});

class WorkflowsNotifier extends StateNotifier<List<Workflow>> {
  WorkflowsNotifier() : super([]) {
    _load();
  }

  void _load() {
    final rows = AppDatabase.instance.getWorkflows();
    state = rows
        .map((r) {
          final nodeJson =
              jsonDecode(r['nodes'] as String? ?? '[]') as List;
          return Workflow(
            id: r['id'] as String,
            name: r['name'] as String,
            description: r['description'] as String? ?? '',
            nodes: nodeJson
                .map((n) => WorkflowNode(
                      id: n['id'] as String,
                      type: WorkflowNodeType.values
                          .firstWhere((t) => t.name == n['type'],
                              orElse: () => WorkflowNodeType.llm),
                      label: n['label'] as String,
                    ))
                .toList(),
          );
        })
        .toList();
  }

  void add(Workflow w) {
    state = [w, ...state];
    AppDatabase.instance.insertWorkflow(
      id: w.id,
      name: w.name,
      description: w.description,
      nodes: jsonEncode(w.nodes.map((n) => {'id': n.id, 'type': n.type.name, 'label': n.label}).toList()),
      status: w.status.name,
      createdAt: w.createdAt.toIso8601String(),
    );
  }

  void remove(String id) {
    state = state.where((w) => w.id != id).toList();
    AppDatabase.instance.deleteWorkflow(id);
  }
}

// ── Workflow templates ────────────────────────────────────────────────────────

final _templates = [
  {
    'name': 'Daily Briefing',
    'description': 'Morning summary of news, weather, and tasks',
    'nodes': ['Trigger: 8:00 AM', 'Fetch news headlines', 'LLM: Summarize', 'Notify: Send summary'],
  },
  {
    'name': 'Research Digest',
    'description': 'Automated deep research on a topic',
    'nodes': ['Trigger: Manual', 'Deep Research', 'LLM: Format report', 'Save to memory'],
  },
  {
    'name': 'Chat Summarizer',
    'description': 'Summarize long conversations into key points',
    'nodes': ['Trigger: Chat session ends', 'LLM: Summarize', 'Memory: Save episodic'],
  },
];

// ── Screen ────────────────────────────────────────────────────────────────────

class WorkflowScreen extends ConsumerStatefulWidget {
  const WorkflowScreen({super.key});

  @override
  ConsumerState<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends ConsumerState<WorkflowScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _createFromTemplate(Map<String, dynamic> template) {
    final nodes = (template['nodes'] as List<String>)
        .map((label) => WorkflowNode(
              type: label.startsWith('Trigger')
                  ? WorkflowNodeType.trigger
                  : label.startsWith('LLM')
                      ? WorkflowNodeType.llm
                      : label.startsWith('Notify') || label.startsWith('Save')
                          ? WorkflowNodeType.output
                          : WorkflowNodeType.tool,
              label: label,
            ))
        .toList();
    final w = Workflow(
      name: template['name'] as String,
      description: template['description'] as String,
      nodes: nodes,
    );
    ref.read(workflowsProvider.notifier).add(w);
    _tabController.animateTo(0);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Created workflow: ${w.name}')));
  }

  Future<void> _runWorkflow(Workflow w) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Running: ${w.name}…')));
    await for (final _ in WorkflowExecutor.instance.execute(w)) {}
  }

  @override
  Widget build(BuildContext context) {
    final workflows = ref.watch(workflowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflows'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Flows'),
            Tab(text: 'Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My workflows
          workflows.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_outlined,
                          size: 56, color: Colors.white12),
                      SizedBox(height: 12),
                      Text(
                        'No workflows yet.\nUse Templates to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: workflows.length,
                  itemBuilder: (_, i) {
                    final w = workflows[i];
                    return _WorkflowCard(
                      workflow: w,
                      onRun: () => _runWorkflow(w),
                      onDelete: () =>
                          ref.read(workflowsProvider.notifier).remove(w.id),
                    );
                  },
                ),

          // Templates
          ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _templates.length,
            itemBuilder: (_, i) {
              final t = _templates[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(t['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(t['description'] as String,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: FilledButton.tonal(
                    onPressed: () => _createFromTemplate(t),
                    child: const Text('Use'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _WorkflowCard extends StatelessWidget {
  final Workflow workflow;
  final VoidCallback onRun;
  final VoidCallback onDelete;
  const _WorkflowCard(
      {required this.workflow, required this.onRun, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_tree, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(workflow.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.white38),
                  onPressed: onDelete),
            ]),
            if (workflow.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(workflow.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            // Node chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: workflow.nodes
                  .map((n) => Chip(
                        label: Text(n.label,
                            style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(_nodeIcon(n.type), size: 14),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRun,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _nodeIcon(WorkflowNodeType t) {
    switch (t) {
      case WorkflowNodeType.trigger:
        return Icons.bolt;
      case WorkflowNodeType.llm:
        return Icons.psychology;
      case WorkflowNodeType.tool:
        return Icons.build;
      case WorkflowNodeType.condition:
        return Icons.call_split;
      case WorkflowNodeType.output:
        return Icons.output;
    }
  }
}
