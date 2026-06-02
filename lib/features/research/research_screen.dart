import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/research/research_engine.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final researchProgressProvider = StateProvider<String>((ref) => '');
final researchRunningProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────

class ResearchScreen extends ConsumerStatefulWidget {
  const ResearchScreen({super.key});

  @override
  ConsumerState<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends ConsumerState<ResearchScreen> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  int _maxSources = 5;

  Future<void> _startResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    ref.read(researchRunningProvider.notifier).state = true;
    ref.read(researchProgressProvider.notifier).state = '';

    final buffer = StringBuffer();
    await for (final chunk
        in ResearchEngine.instance.research(query: query, maxSources: _maxSources)) {
      if (!mounted) break;
      buffer.write(chunk);
      ref.read(researchProgressProvider.notifier).state = buffer.toString();
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }

    ref.read(researchRunningProvider.notifier).state = false;
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(researchProgressProvider);
    final running = ref.watch(researchRunningProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Research'),
        actions: [
          if (running)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Query input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        decoration: const InputDecoration(
                          hintText: 'What do you want to research?',
                          prefixIcon: Icon(Icons.search, size: 20),
                        ),
                        onSubmitted: (_) => running ? null : _startResearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: running ? null : _startResearch,
                      child: const Text('Research'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Sources: $_maxSources',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white54)),
                    Expanded(
                      child: Slider(
                        value: _maxSources.toDouble(),
                        min: 3,
                        max: 10,
                        divisions: 7,
                        onChanged: (v) =>
                            setState(() => _maxSources = v.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),

          // Research output
          Expanded(
            child: progress.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_outlined,
                            size: 56, color: Colors.white12),
                        SizedBox(height: 12),
                        Text(
                          'Enter a research query above.\nDevPilot will decompose it, search the web,\nread sources, and synthesize a report.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, height: 1.5),
                        ),
                      ],
                    ),
                  )
                : Markdown(
                    controller: _scrollController,
                    data: progress,
                    padding: const EdgeInsets.all(16),
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 14, height: 1.6),
                      h1: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      h2: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      code: TextStyle(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      blockquote: const TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.white54),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
