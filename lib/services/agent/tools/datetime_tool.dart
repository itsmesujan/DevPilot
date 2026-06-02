import '../../../models/agent_models.dart';

class DateTimeTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'datetime',
        description: 'Get the current date and time, or format a date.',
        type: ToolType.datetime,
        parameters: {
          'action': ParameterDefinition(
            type: 'string',
            description: 'Action to perform: "current_time" or "format"',
            required: false,
            enumValues: ['current_time', 'format'],
            defaultValue: 'current_time',
          ),
          'format': ParameterDefinition(
            type: 'string',
            description: 'Format string (optional, e.g. "yyyy-MM-dd HH:mm:ss")',
            required: false,
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? 'current_time';
    final now = DateTime.now();

    if (action == 'current_time') {
      return 'Current date and time: ${now.toIso8601String()}\nLocal time: ${now.toString()}';
    }
    return 'Current date and time: ${now.toString()}';
  }
}
