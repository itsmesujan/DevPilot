import 'package:uuid/uuid.dart';

enum AgentStatus { idle, planning, running, paused, done, failed }

enum ToolType {
  webSearch,
  urlReader,
  calculator,
  codeRunner,
  fileBrowser,
  imageGen,
  translate,
  noteCreator,
  weatherFetch,
  deviceInfo,
  datetime,
  unitConverter,
  textProcessor,
  knowledgeSearch,
}

/// Represents a single step in the agent's thinking process
class AgentStep {
  final String id;
  final String thought;
  final ToolType? tool;
  final String? toolInput;
  final String? toolOutput;
  final DateTime timestamp;

  AgentStep({
    String? id,
    required this.thought,
    this.tool,
    this.toolInput,
    this.toolOutput,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();
}

/// Represents an agent task with goal and execution state
class AgentTask {
  final String id;
  final String goal;
  AgentStatus status;
  final List<AgentStep> steps;
  String? finalAnswer;
  final DateTime createdAt;

  AgentTask({
    String? id,
    required this.goal,
    this.status = AgentStatus.idle,
    List<AgentStep>? steps,
    this.finalAnswer,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        steps = steps ?? [],
        createdAt = createdAt ?? DateTime.now();
}

/// Types of thinking steps in chain-of-thought reasoning
enum ThinkingType {
  understanding,    // Analyzing the goal
  planning,         // Breaking down into subtasks
  toolPlanning,     // Deciding which tools to use
  reasoning,        // Working on a subtask
  toolDecision,     // Deciding to call a specific tool
  toolExecution,    // Actually executing a tool
  toolResult,       // Processing tool result
  reflection,       // Evaluating progress
  synthesis,        // Combining results
  finalAnswer,      // Generating final response
  error,            // Error handling
}

/// Represents a single thinking step with metadata
class ThinkingStep {
  final String id;
  final ThinkingType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final Duration? duration;

  ThinkingStep({
    String? id,
    required this.type,
    required this.content,
    DateTime? timestamp,
    this.metadata = const {},
    this.duration,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'duration': duration?.inMilliseconds,
      };

  factory ThinkingStep.fromJson(Map<String, dynamic> json) => ThinkingStep(
        id: json['id'] as String,
        type: ThinkingType.values.byName(json['type'] as String),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        duration: json['duration'] != null
            ? Duration(milliseconds: json['duration'] as int)
            : null,
      );

  /// Get display icon for thinking type
  String get icon {
    switch (type) {
      case ThinkingType.understanding:
        return '🔍';
      case ThinkingType.planning:
        return '📋';
      case ThinkingType.toolPlanning:
        return '🛠️';
      case ThinkingType.reasoning:
        return '🧠';
      case ThinkingType.toolDecision:
        return '⚙️';
      case ThinkingType.toolExecution:
        return '⚡';
      case ThinkingType.toolResult:
        return '📦';
      case ThinkingType.reflection:
        return '💭';
      case ThinkingType.synthesis:
        return '🔗';
      case ThinkingType.finalAnswer:
        return '✅';
      case ThinkingType.error:
        return '❌';
    }
  }

  /// Get display label for thinking type
  String get label {
    switch (type) {
      case ThinkingType.understanding:
        return 'Understanding';
      case ThinkingType.planning:
        return 'Planning';
      case ThinkingType.toolPlanning:
        return 'Tool Planning';
      case ThinkingType.reasoning:
        return 'Reasoning';
      case ThinkingType.toolDecision:
        return 'Tool Decision';
      case ThinkingType.toolExecution:
        return 'Executing Tool';
      case ThinkingType.toolResult:
        return 'Tool Result';
      case ThinkingType.reflection:
        return 'Reflecting';
      case ThinkingType.synthesis:
        return 'Synthesizing';
      case ThinkingType.finalAnswer:
        return 'Final Answer';
      case ThinkingType.error:
        return 'Error';
    }
  }
}

/// Definition of a tool that the agent can use
class ToolDefinition {
  final String name;
  final String description;
  final ToolType type;
  final Map<String, ParameterDefinition> parameters;
  final Future<String> Function(Map<String, dynamic> args) execute;

  ToolDefinition({
    required this.name,
    required this.description,
    required this.type,
    required this.parameters,
    required this.execute,
  });

  /// Convert to OpenAI function calling format
  Map<String, dynamic> toOpenAIFunction() => {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': parameters.map((key, value) => MapEntry(key, value.toJson())),
          'required': parameters.entries
              .where((e) => e.value.required)
              .map((e) => e.key)
              .toList(),
        },
      };

  /// Convert to Anthropic tool use format
  Map<String, dynamic> toAnthropicTool() => {
        'name': name,
        'description': description,
        'input_schema': {
          'type': 'object',
          'properties': parameters.map((key, value) => MapEntry(key, value.toJson())),
          'required': parameters.entries
              .where((e) => e.value.required)
              .map((e) => e.key)
              .toList(),
        },
      };
}

/// Definition of a tool parameter
class ParameterDefinition {
  final String type; // string, number, boolean, array, object
  final String description;
  final bool required;
  final List<String>? enumValues;
  final dynamic defaultValue;

  ParameterDefinition({
    required this.type,
    required this.description,
    this.required = true,
    this.enumValues,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        if (enumValues != null) 'enum': enumValues,
      };
}

/// Result of a tool execution
class ToolResult {
  final String toolName;
  final String input;
  final String output;
  final bool success;
  final String? error;
  final Duration duration;
  final DateTime timestamp;

  ToolResult({
    required this.toolName,
    required this.input,
    required this.output,
    this.success = true,
    this.error,
    required this.duration,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'toolName': toolName,
        'input': input,
        'output': output,
        'success': success,
        'error': error,
        'duration': duration.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Agent execution context that tracks state during a run
class AgentContext {
  final String goal;
  final List<ThinkingStep> thinkingSteps;
  final List<ToolResult> toolResults;
  final List<AgentStep> agentSteps;
  final Map<String, dynamic> variables;
  int iterationCount;
  final int maxIterations;

  AgentContext({
    required this.goal,
    List<ThinkingStep>? thinkingSteps,
    List<ToolResult>? toolResults,
    List<AgentStep>? agentSteps,
    Map<String, dynamic>? variables,
    this.maxIterations = 10,
  })  : thinkingSteps = thinkingSteps ?? [],
        toolResults = toolResults ?? [],
        agentSteps = agentSteps ?? [],
        variables = variables ?? {},
        iterationCount = 0;

  bool get canContinue => iterationCount < maxIterations;

  void incrementIteration() => iterationCount++;

  void addThinkingStep(ThinkingStep step) => thinkingSteps.add(step);

  void addToolResult(ToolResult result) => toolResults.add(result);

  void addAgentStep(AgentStep step) => agentSteps.add(step);

  void setVariable(String key, dynamic value) => variables[key] = value;

  dynamic getVariable(String key) => variables[key];
}