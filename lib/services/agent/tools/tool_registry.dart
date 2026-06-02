import '../../../models/agent_models.dart';

/// Registry for all available agent tools
class ToolRegistry {
  ToolRegistry._();
  static final ToolRegistry instance = ToolRegistry._();

  final Map<String, ToolDefinition> _tools = {};

  /// Register a new tool
  void register(ToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  /// Unregister a tool by name
  void unregister(String name) {
    _tools.remove(name);
  }

  /// Get a tool by name
  ToolDefinition? get(String name) => _tools[name];

  /// Check if a tool exists
  bool has(String name) => _tools.containsKey(name);

  /// Get all registered tools
  List<ToolDefinition> get allTools => _tools.values.toList();

  /// Get all tool names
  List<String> get toolNames => _tools.keys.toList();

  /// Execute a tool by name
  Future<ToolResult> execute(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult(
        toolName: name,
        input: args.toString(),
        output: '',
        success: false,
        error: 'Tool "$name" not found',
        duration: Duration.zero,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final output = await tool.execute(args);
      stopwatch.stop();
      return ToolResult(
        toolName: name,
        input: args.toString(),
        output: output,
        success: true,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ToolResult(
        toolName: name,
        input: args.toString(),
        output: '',
        success: false,
        error: e.toString(),
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Clear all registered tools
  void clear() => _tools.clear();

  /// Get tool count
  int get count => _tools.length;
}