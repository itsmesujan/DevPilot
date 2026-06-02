import '../../../models/agent_models.dart';

class TextProcessorTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'text_processor',
        description: 'Process and analyze text content (word count, case conversion, reverse text).',
        type: ToolType.textProcessor,
        parameters: {
          'text': ParameterDefinition(
            type: 'string',
            description: 'The text to process',
            required: true,
          ),
          'operation': ParameterDefinition(
            type: 'string',
            description: 'Operation to perform: "word_count", "uppercase", "lowercase", "reverse"',
            required: true,
            enumValues: ['word_count', 'uppercase', 'lowercase', 'reverse'],
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final operation = args['operation'] as String;

    switch (operation) {
      case 'word_count':
        final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        final chars = text.length;
        final lines = text.split('\n').length;
        return 'Text Statistics:\n• Word count: $words\n• Character count: $chars\n• Line count: $lines';
      case 'uppercase':
        return text.toUpperCase();
      case 'lowercase':
        return text.toLowerCase();
      case 'reverse':
        return text.split('').reversed.join('');
      default:
        return 'Unsupported operation: $operation';
    }
  }
}
