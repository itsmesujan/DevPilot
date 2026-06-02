import 'dart:async';
import 'dart:convert';
import '../../models/agent_models.dart';
import '../../models/chat_message.dart';
import '../ai/ai_client.dart';
import '../storage/storage_service.dart';
import 'thinking_engine.dart';
import 'tools/tool_registry.dart';
import 'tools/builtin_tools.dart';

/// Agent event types for streaming updates
enum AgentEventType {
  thinking,
  toolCall,
  toolResult,
  text,
  progress,
  error,
  complete,
}

/// Agent event for streaming updates
class AgentEvent {
  final AgentEventType type;
  final String content;
  final ThinkingStep? thinkingStep;
  final ToolResult? toolResult;
  final Map<String, dynamic> metadata;

  AgentEvent({
    required this.type,
    required this.content,
    this.thinkingStep,
    this.toolResult,
    this.metadata = const {},
  });
}

/// Enhanced Agent Orchestrator with ReAct (Reasoning + Acting) loop
/// Implements chain-of-thought reasoning with tool use
class AgentOrchestrator {
  AgentOrchestrator._();
  static final AgentOrchestrator instance = AgentOrchestrator._();

  bool _initialized = false;

  /// Initialize the agent with all built-in tools
  Future<void> init() async {
    if (_initialized) return;

    // Register all built-in tools
    BuiltinTools.registerAll();

    _initialized = true;
  }

  /// Get the list of available tools
  List<ToolDefinition> get availableTools => ToolRegistry.instance.allTools;

  /// Run the agent with streaming events
  Stream<AgentEvent> run({
    required String goal,
    List<ChatMessage> context = const [],
    int maxIterations = 10,
    bool useThinking = true,
  }) async* {
    await init();

    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    // Create execution context
    final agentContext = AgentContext(
      goal: goal,
      maxIterations: maxIterations,
    );

    yield AgentEvent(
      type: AgentEventType.progress,
      content: 'Starting agent for: $goal',
    );

    // Phase 1: Thinking (if enabled)
    if (useThinking) {
      yield* _runThinkingPhase(
        goal: goal,
        provider: provider,
        modelId: modelId,
        context: context,
        agentContext: agentContext,
      );
    }

    // Phase 2: ReAct Loop (Reasoning + Acting)
    yield* _runReActLoop(
      goal: goal,
      provider: provider,
      modelId: modelId,
      context: context,
      agentContext: agentContext,
    );

    // Phase 3: Final Synthesis
    yield* _runSynthesisPhase(
      goal: goal,
      provider: provider,
      modelId: modelId,
      agentContext: agentContext,
    );

    yield AgentEvent(
      type: AgentEventType.complete,
      content: 'Agent completed successfully',
      metadata: {
        'iterations': agentContext.iterationCount,
        'toolCalls': agentContext.toolResults.length,
        'thinkingSteps': agentContext.thinkingSteps.length,
      },
    );
  }

  /// Run the thinking/planning phase
  Stream<AgentEvent> _runThinkingPhase({
    required String goal,
    required String provider,
    required String modelId,
    required List<ChatMessage> context,
    required AgentContext agentContext,
  }) async* {
    yield AgentEvent(
      type: AgentEventType.progress,
      content: '🧠 Planning approach...',
    );

    await for (final step in ThinkingEngine.instance.think(
      goal: goal,
      provider: provider,
      modelId: modelId,
      context: context,
      availableTools: availableTools,
    )) {
      agentContext.addThinkingStep(step);
      yield AgentEvent(
        type: AgentEventType.thinking,
        content: step.content,
        thinkingStep: step,
      );
    }
  }

  /// Run the ReAct (Reasoning + Acting) loop
  Stream<AgentEvent> _runReActLoop({
    required String goal,
    required String provider,
    required String modelId,
    required List<ChatMessage> context,
    required AgentContext agentContext,
  }) async* {
    final conversationHistory = <ChatMessage>[
      ...context,
      ChatMessage(
        role: MessageRole.user,
        content: goal,
      ),
    ];

    while (agentContext.canContinue) {
      agentContext.incrementIteration();

      yield AgentEvent(
        type: AgentEventType.progress,
        content: 'Iteration ${agentContext.iterationCount}/${agentContext.maxIterations}',
      );

      // Get AI's decision on what to do next
      final decision = await _getAIDecision(
        goal: goal,
        provider: provider,
        modelId: modelId,
        history: conversationHistory,
        previousResults: agentContext.toolResults,
      );

      // Check if we should finish
      if (decision.action == 'finish') {
        yield AgentEvent(
          type: AgentEventType.progress,
          content: 'AI decided to finish',
        );
        break;
      }

      // Execute tool if requested
      if (decision.action == 'tool' && decision.toolName != null) {
        yield AgentEvent(
          type: AgentEventType.toolCall,
          content: 'Calling tool: ${decision.toolName}',
          metadata: {
            'toolName': decision.toolName,
            'arguments': decision.arguments,
            'reasoning': decision.reasoning,
          },
        );

        // Execute the tool
        final result = await ToolRegistry.instance.execute(
          decision.toolName!,
          decision.arguments ?? {},
        );

        agentContext.addToolResult(result);

        yield AgentEvent(
          type: AgentEventType.toolResult,
          content: result.success ? 'Tool completed' : 'Tool failed: ${result.error}',
          toolResult: result,
        );

        // Add tool result to conversation
        conversationHistory.add(ChatMessage(
          role: MessageRole.tool,
          content: 'Tool: ${decision.toolName}\nResult: ${result.output}',
        ));
      } else if (decision.action == 'think') {
        // AI wants to think more
        yield AgentEvent(
          type: AgentEventType.thinking,
          content: decision.reasoning ?? 'Continuing to reason...',
          thinkingStep: ThinkingStep(
            type: ThinkingType.reasoning,
            content: decision.reasoning ?? '',
          ),
        );

        conversationHistory.add(ChatMessage(
          role: MessageRole.assistant,
          content: decision.reasoning ?? '',
        ));
      }
    }
  }

  /// Get AI's decision on what action to take
  Future<_AIDecision> _getAIDecision({
    required String goal,
    required String provider,
    required String modelId,
    required List<ChatMessage> history,
    required List<ToolResult> previousResults,
  }) async {
    final toolsDescription = availableTools
        .map((t) => '- ${t.name}: ${t.description}')
        .join('\n');

    final previousResultsStr = previousResults.isEmpty
        ? 'None yet'
        : previousResults
            .map((r) => '• ${r.toolName}: ${r.output.substring(0, r.output.length > 100 ? 100 : r.output.length)}...')
            .join('\n');

    final systemPrompt = '''You are an AI agent that can use tools to accomplish goals.

Available tools:
$toolsDescription

Previous tool results:
$previousResultsStr

Your goal: $goal

Decide your next action. Respond in this exact JSON format:
{
  "action": "tool" | "think" | "finish",
  "tool_name": "name_of_tool" (if action is "tool"),
  "arguments": {"param": "value"} (if action is "tool"),
  "reasoning": "Why you chose this action"
}

Rules:
- Use "tool" when you need information or want to perform an action
- Use "think" when you want to reason about the problem without tools
- Use "finish" when you have enough information to provide a final answer
- Only use ONE tool at a time
- Be specific with tool arguments''';

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: history,
      systemPrompt: systemPrompt,
      temperature: 0.3,
      maxTokens: 500,
    )) {
      buffer.write(chunk);
    }

    final response = buffer.toString();

    try {
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return _AIDecision(
          action: json['action'] as String? ?? 'think',
          toolName: json['tool_name'] as String?,
          arguments: json['arguments'] as Map<String, dynamic>?,
          reasoning: json['reasoning'] as String?,
        );
      }
    } catch (_) {}

    // Fallback: if no JSON, assume thinking
    return _AIDecision(
      action: 'think',
      reasoning: response,
    );
  }

  /// Run the final synthesis phase
  Stream<AgentEvent> _runSynthesisPhase({
    required String goal,
    required String provider,
    required String modelId,
    required AgentContext agentContext,
  }) async* {
    yield AgentEvent(
      type: AgentEventType.progress,
      content: '📝 Synthesizing final answer...',
    );

    // Build context from tool results
    final toolResultsSummary = agentContext.toolResults.isEmpty
        ? 'No tools were used.'
        : agentContext.toolResults
            .map((r) => '''
Tool: ${r.toolName}
Input: ${r.input}
Result: ${r.output}
''')
            .join('\n---\n');

    final thinkingSummary = agentContext.thinkingSteps.isEmpty
        ? ''
        : '\nThinking process:\n${agentContext.thinkingSteps.map((s) => '• ${s.label}: ${s.content}').join('\n')}';

    final prompt = '''Based on the following information, provide a comprehensive answer to the goal.

Goal: $goal

Tool Results:
$toolResultsSummary
$thinkingSummary

Provide a well-structured, complete answer. Use markdown formatting for clarity.''';

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: prompt),
      ],
      systemPrompt: 'You are a helpful assistant. Provide comprehensive, well-structured answers based on the information gathered. Use markdown formatting.',
      temperature: 0.5,
      maxTokens: 2000,
    )) {
      buffer.write(chunk);
      yield AgentEvent(
        type: AgentEventType.text,
        content: chunk,
      );
    }

    yield AgentEvent(
      type: AgentEventType.progress,
      content: '✅ Final answer generated',
    );
  }

  /// Simple agent run without thinking (for quick tasks)
  Stream<String> runSimple(String goal) async* {
    await init();

    final storage = StorageService.instance;
    final provider = storage.selectedProvider;
    final modelId = storage.selectedModelId;

    yield 'Working on: $goal\n\n';

    // Simple direct execution without thinking
    final toolsDescription = availableTools
        .map((t) => '- ${t.name}: ${t.description}')
        .join('\n');

    final buffer = StringBuffer();
    await for (final chunk in AiClient.instance.streamChat(
      provider: provider,
      modelId: modelId,
      messages: [
        ChatMessage(role: MessageRole.user, content: goal),
      ],
      systemPrompt: '''You are a helpful AI assistant with access to these tools:
$toolsDescription

If you need to use a tool, format your response as:
TOOL_CALL: tool_name
ARGUMENTS: {"param": "value"}
END_TOOL

Otherwise, provide a direct answer to the user's request.''',
      temperature: 0.5,
      maxTokens: 1500,
    )) {
      buffer.write(chunk);
      yield chunk;
    }

    // Check for tool calls in response
    final response = buffer.toString();
    final toolCallMatch = RegExp(r'TOOL_CALL:\s*(\w+)\s*ARGUMENTS:\s*(\{.*?\})\s*END_TOOL', dotAll: true)
        .firstMatch(response);

    if (toolCallMatch != null) {
      final toolName = toolCallMatch.group(1)!;
      final argsStr = toolCallMatch.group(2)!;

      yield '\n\n🔧 Using tool: $toolName\n';

      try {
        final args = jsonDecode(argsStr) as Map<String, dynamic>;
        final result = await ToolRegistry.instance.execute(toolName, args);

        if (result.success) {
          yield '✅ Result:\n${result.output}\n\n';
        } else {
          yield '❌ Error: ${result.error}\n\n';
        }
      } catch (e) {
        yield '❌ Tool execution error: $e\n\n';
      }
    }
  }
}

/// AI decision structure
class _AIDecision {
  final String action; // 'tool', 'think', 'finish'
  final String? toolName;
  final Map<String, dynamic>? arguments;
  final String? reasoning;

  _AIDecision({
    required this.action,
    this.toolName,
    this.arguments,
    this.reasoning,
  });
}