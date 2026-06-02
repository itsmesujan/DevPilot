import 'dart:async';
import 'dart:convert';
import '../ai/ai_client.dart';
import '../../models/chat_message.dart';
import '../../models/agent_models.dart';

/// ThinkingEngine implements chain-of-thought (CoT) and tree-of-thought (ToT)
/// reasoning for complex problem solving.
class ThinkingEngine {
  ThinkingEngine._();
  static final ThinkingEngine instance = ThinkingEngine._();

  /// Generate a thinking chain for the given goal
  Stream<ThinkingStep> think({
    required String goal,
    required String provider,
    required String modelId,
    List<ChatMessage> context = const [],
    List<ToolDefinition> availableTools = const [],
  }) async* {
    // Step 1: Understand the goal
    yield ThinkingStep(
      type: ThinkingType.understanding,
      content: 'Analyzing the goal: $goal',
      timestamp: DateTime.now(),
    );

    // Step 2: Decompose into subtasks
    final subtasks = await _decomposeGoal(goal, provider, modelId, context);
    yield ThinkingStep(
      type: ThinkingType.planning,
      content: 'Breaking down into ${subtasks.length} subtasks:\n${subtasks.map((s) => '• $s').join('\n')}',
      timestamp: DateTime.now(),
      metadata: {'subtasks': subtasks},
    );

    // Step 3: Determine which tools might be needed
    final toolPlan = await _planToolUsage(subtasks, availableTools, provider, modelId);
    yield ThinkingStep(
      type: ThinkingType.toolPlanning,
      content: 'Tool usage plan:\n${toolPlan.map((t) => '• ${t.toolName}: ${t.purpose}').join('\n')}',
      timestamp: DateTime.now(),
      metadata: {'toolPlan': toolPlan.map((t) => t.toJson()).toList()},
    );

    // Step 4: Execute reasoning chain
    for (var i = 0; i < subtasks.length; i++) {
      final subtask = subtasks[i];
      final plannedTool = i < toolPlan.length ? toolPlan[i] : null;

      yield ThinkingStep(
        type: ThinkingType.reasoning,
        content: 'Working on subtask ${i + 1}: $subtask',
        timestamp: DateTime.now(),
        metadata: {'subtaskIndex': i, 'plannedTool': plannedTool?.toolName},
      );

      // Determine if we need a tool
      if (plannedTool != null && plannedTool.toolName != 'none') {
        yield ThinkingStep(
          type: ThinkingType.toolDecision,
          content: 'Decision: Using tool "${plannedTool.toolName}" - ${plannedTool.reasoning}',
          timestamp: DateTime.now(),
          metadata: {
            'toolName': plannedTool.toolName,
            'input': plannedTool.input,
          },
        );
      }
    }

    // Step 5: Synthesize final answer plan
    yield ThinkingStep(
      type: ThinkingType.synthesis,
      content: 'Planning final response synthesis...',
      timestamp: DateTime.now(),
    );
  }

  /// Decompose a goal into manageable subtasks
  Future<List<String>> _decomposeGoal(
    String goal,
    String provider,
    String modelId,
    List<ChatMessage> context,
  ) async {
    final prompt = '''Analyze this goal and break it down into specific subtasks.
Goal: $goal

Output ONLY the subtasks, one per line, starting with a verb.
Example format:
Search for information about X
Analyze the results to find Y
Calculate Z based on the findings
Provide a comprehensive answer

Subtasks:''';

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ...context.take(3), // Include recent context
        ChatMessage(role: MessageRole.user, content: prompt),
      ],
      systemPrompt: 'You are a task decomposition expert. Break complex goals into clear, actionable subtasks. Be specific and concise.',
      temperature: 0.3,
      maxTokens: 300,
    )) {
      buffer.write(chunk);
    }

    return buffer
        .toString()
        .split('\n')
        .map((line) => line.trim().replaceFirst(RegExp(r'^\d+[\.\)]\s*'), ''))
        .where((line) => line.isNotEmpty && line.length > 5)
        .take(5)
        .toList();
  }

  /// Plan which tools to use for each subtask
  Future<List<ToolPlan>> _planToolUsage(
    List<String> subtasks,
    List<ToolDefinition> availableTools,
    String provider,
    String modelId,
  ) async {
    if (availableTools.isEmpty) {
      return subtasks.map((_) => ToolPlan(toolName: 'none', purpose: 'Direct response', input: '', reasoning: 'No tools available')).toList();
    }

    final toolsDescription = availableTools
        .map((t) => '- ${t.name}: ${t.description}')
        .join('\n');

    final prompt = '''For each subtask, decide which tool to use (if any).

Available tools:
$toolsDescription
- none: Use when no tool is needed (direct AI response)

Subtasks:
${subtasks.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Output JSON array format:
[{"subtask": 1, "tool": "tool_name", "input": "what to pass", "purpose": "why", "reasoning": "why this tool"}]''';

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [ChatMessage(role: MessageRole.user, content: prompt)],
      systemPrompt: 'You are a tool usage planner. Match subtasks to appropriate tools. Output ONLY valid JSON.',
      temperature: 0.2,
      maxTokens: 500,
    )) {
      buffer.write(chunk);
    }

    try {
      final response = buffer.toString();
      // Extract JSON from response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final List<dynamic> plans = jsonDecode(jsonMatch.group(0)!);
        return plans.map((p) => ToolPlan(
          toolName: p['tool'] ?? 'none',
          purpose: p['purpose'] ?? '',
          input: p['input'] ?? '',
          reasoning: p['reasoning'] ?? '',
        )).toList();
      }
    } catch (_) {}

    // Fallback: no tool planning
    return subtasks.map((_) => ToolPlan(toolName: 'none', purpose: 'Direct response', input: '', reasoning: 'Fallback')).toList();
  }

  /// Generate reflection on the results
  Future<String> reflect({
    required String originalGoal,
    required List<ToolResult> results,
    required String provider,
    required String modelId,
  }) async {
    final resultsSummary = results.map((r) => 
      'Tool: ${r.toolName}\nInput: ${r.input}\nResult: ${r.output.substring(0, r.output.length > 200 ? 200 : r.output.length)}...'
    ).join('\n\n');

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: '''Reflect on these results and determine if the goal was achieved.

Original Goal: $originalGoal

Tool Results:
$resultsSummary

Is the goal complete? What additional information might be needed? Provide a brief reflection.'''),
      ],
      systemPrompt: 'You are a critical thinker. Evaluate results objectively and identify gaps.',
      temperature: 0.3,
      maxTokens: 300,
    )) {
      buffer.write(chunk);
    }

    return buffer.toString();
  }
}

/// Represents a planned tool usage
class ToolPlan {
  final String toolName;
  final String purpose;
  final String input;
  final String reasoning;

  ToolPlan({
    required this.toolName,
    required this.purpose,
    required this.input,
    required this.reasoning,
  });

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'purpose': purpose,
    'input': input,
    'reasoning': reasoning,
  };
}