import 'dart:async';
import '../../models/workflow_models.dart';
import '../ai/ai_client.dart';
import '../storage/storage_service.dart';
import '../../models/chat_message.dart';

class WorkflowExecutor {
  WorkflowExecutor._();
  static final WorkflowExecutor instance = WorkflowExecutor._();

  Stream<String> execute(Workflow workflow) async* {
    workflow.status = WorkflowStatus.running;
    workflow.lastRunAt = DateTime.now();

    yield '**Running workflow:** ${workflow.name}\n\n';

    // Find trigger node
    final trigger = workflow.nodes.where((n) => n.type == WorkflowNodeType.trigger).firstOrNull;
    if (trigger == null) {
      yield 'Error: No trigger node found.\n';
      workflow.status = WorkflowStatus.failed;
      return;
    }

    // Execute nodes in sequence
    var currentNodeId = trigger.nextIds.firstOrNull;
    final executionContext = <String, String>{};

    while (currentNodeId != null) {
      final node = workflow.nodes.where((n) => n.id == currentNodeId).firstOrNull;
      if (node == null) break;

      yield '**Node:** ${node.label}\n';

      switch (node.type) {
        case WorkflowNodeType.llm:
          final prompt = _interpolate(node.config['prompt'] as String? ?? '', executionContext);
          final result = await _runLlmNode(prompt);
          executionContext['${node.id}_output'] = result;
          executionContext['last_output'] = result;
          yield 'LLM output: $result\n\n';

        case WorkflowNodeType.tool:
          final toolName = node.config['tool'] as String? ?? '';
          final toolInput = _interpolate(node.config['input'] as String? ?? '', executionContext);
          final result = 'Tool $toolName executed with: $toolInput';
          executionContext['last_output'] = result;
          yield '$result\n\n';

        case WorkflowNodeType.condition:
          final condition = node.config['condition'] as String? ?? '';
          final passed = _evaluateCondition(condition, executionContext);
          yield 'Condition "$condition": ${passed ? "true" : "false"}\n\n';
          if (!passed) {
            currentNodeId = null;
            break;
          }

        case WorkflowNodeType.output:
          final template = _interpolate(node.config['template'] as String? ?? '{{last_output}}', executionContext);
          yield '**Output:** $template\n';

        default:
          yield 'Skipping node type: ${node.type.name}\n';
      }

      currentNodeId = node.nextIds.firstOrNull;
    }

    workflow.status = WorkflowStatus.done;
    yield '\n**Workflow complete.**\n';
  }

  Future<String> _runLlmNode(String prompt) async {
    final provider = StorageService.instance.selectedProvider;
    final modelId = StorageService.instance.selectedModelId;
    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [ChatMessage(role: MessageRole.user, content: prompt)],
      temperature: 0.5,
      maxTokens: 512,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  String _interpolate(String template, Map<String, String> ctx) {
    var result = template;
    for (final entry in ctx.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  bool _evaluateCondition(String condition, Map<String, String> ctx) {
    final resolved = _interpolate(condition, ctx);
    return resolved.isNotEmpty && resolved.toLowerCase() != 'false';
  }
}
