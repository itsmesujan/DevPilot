import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/agent/agent_orchestrator.dart';
import '../../models/agent_models.dart';

/// Agent screen with thinking visualization and tool call display
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _goalController = TextEditingController();
  final _scrollController = ScrollController();
  final _orchestrator = AgentOrchestrator.instance;
  
  bool _isRunning = false;
  String _currentStatus = '';
  String _finalAnswer = '';
  final List<AgentEvent> _events = [];
  final List<ThinkingStep> _thinkingSteps = [];
  final List<ToolResult> _toolResults = [];

  Future<void> _runAgent() async {
    if (_goalController.text.isEmpty) return;

    setState(() {
      _isRunning = true;
      _events.clear();
      _thinkingSteps.clear();
      _toolResults.clear();
      _finalAnswer = '';
      _currentStatus = 'Starting...';
    });

    try {
      await for (final event in _orchestrator.run(
        goal: _goalController.text,
        useThinking: true,
      )) {
        if (!mounted) break;

        setState(() {
          _events.add(event);
          _currentStatus = event.content;

          if (event.thinkingStep != null) {
            _thinkingSteps.add(event.thinkingStep!);
          }
          if (event.toolResult != null) {
            _toolResults.add(event.toolResult!);
          }
          if (event.type == AgentEventType.text) {
            _finalAnswer += event.content;
          }
        });

        // Auto-scroll to bottom
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStatus = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent'),
        actions: [
          if (_isRunning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Goal Input
          _buildGoalInput(theme),

          // Status Bar
          if (_isRunning || _currentStatus.isNotEmpty)
            _buildStatusBar(theme),

          // Main Content
          Expanded(
            child: _finalAnswer.isEmpty && _thinkingSteps.isEmpty
                ? _buildEmptyState(theme)
                : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _goalController,
              decoration: InputDecoration(
                hintText: 'What would you like the agent to do?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.psychology),
                suffixIcon: _isRunning
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _runAgent,
                      ),
              ),
              onSubmitted: (_) => _isRunning ? null : _runAgent(),
              enabled: !_isRunning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isRunning
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          if (_isRunning)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentStatus,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_thinkingSteps.length} steps • ${_toolResults.length} tools',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'AI Agent Ready',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a goal and the agent will think, search, and act to accomplish it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Search the web for latest AI news'),
              _buildSuggestionChip('Calculate 15% tip on \$47.50'),
              _buildSuggestionChip('What is the weather in Tokyo?'),
              _buildSuggestionChip('Summarize this article: [url]'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: _isRunning
          ? null
          : () {
              _goalController.text = text;
              _runAgent();
            },
    );
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Thinking Steps
        if (_thinkingSteps.isNotEmpty) ...[
          _buildSectionHeader(theme, '🧠 Thinking Process', _thinkingSteps.length),
          const SizedBox(height: 8),
          ..._thinkingSteps.map((step) => _buildThinkingStep(theme, step)),
          const SizedBox(height: 16),
        ],

        // Tool Results
        if (_toolResults.isNotEmpty) ...[
          _buildSectionHeader(theme, '🛠️ Tool Calls', _toolResults.length),
          const SizedBox(height: 8),
          ..._toolResults.map((result) => _buildToolResult(theme, result)),
          const SizedBox(height: 16),
        ],

        // Final Answer
        if (_finalAnswer.isNotEmpty) ...[
          _buildSectionHeader(theme, '✅ Final Answer', 1),
          const SizedBox(height: 8),
          _buildFinalAnswer(theme),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  Widget _buildThinkingStep(ThemeData theme, ThinkingStep step) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.icon,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1);
  }

  Widget _buildToolResult(ThemeData theme, ToolResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: result.success
          ? theme.colorScheme.surface
          : theme.colorScheme.errorContainer,
      child: ExpansionTile(
        leading: Icon(
          result.success ? Icons.check_circle : Icons.error,
          color: result.success ? Colors.green : theme.colorScheme.error,
        ),
        title: Text(
          result.toolName,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          '${result.duration.inMilliseconds}ms',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.input.isNotEmpty) ...[
                  Text('Input:', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.input,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text('Output:', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.output.length > 500
                        ? '${result.output.substring(0, 500)}...'
                        : result.output,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (result.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${result.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildFinalAnswer(ThemeData theme) {
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MarkdownBody(
          data: _finalAnswer,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  @override
  void dispose() {
    _goalController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
