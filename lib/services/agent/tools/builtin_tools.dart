import '../../../models/agent_models.dart';
import 'tool_registry.dart';
import 'web_search_tool.dart';
import 'url_reader_tool.dart';
import 'calculator_tool.dart';
import 'datetime_tool.dart';
import 'text_processor_tool.dart';

/// Initializes all built-in tools and registers them with the ToolRegistry
class BuiltinTools {
  /// Register all built-in tools
  static void registerAll() {
    final registry = ToolRegistry.instance;

    // Web search tools
    registry.register(WebSearchTool.definition);
    registry.register(BraveSearchTool.definition);
    registry.register(TavilySearchTool.definition);

    // URL reading tools
    registry.register(UrlReaderTool.definition);
    registry.register(WebScraperTool.definition);

    // Calculation tools
    registry.register(CalculatorTool.definition);
    registry.register(UnitConverterTool.definition);

    // DateTime tools
    registry.register(DateTimeTool.definition);

    // Text processing tools
    registry.register(TextProcessorTool.definition);

    // Knowledge/Note tools (placeholder - will be implemented with memory feature)
    registry.register(_createNoteTool());
    registry.register(_createKnowledgeSearchTool());
  }

  /// Create note tool
  static ToolDefinition _createNoteTool() {
    return ToolDefinition(
      name: 'create_note',
      description: 'Create or save a note with the given title and content for later reference.',
      type: ToolType.noteCreator,
      parameters: {
        'title': ParameterDefinition(
          type: 'string',
          description: 'The title of the note',
          required: true,
        ),
        'content': ParameterDefinition(
          type: 'string',
          description: 'The content of the note',
          required: true,
        ),
        'tags': ParameterDefinition(
          type: 'string',
          description: 'Comma-separated tags for categorization',
          required: false,
        ),
      },
      execute: (args) async {
        final title = args['title'] as String;
        final content = args['content'] as String;
        final tags = args['tags'] as String? ?? '';

        // TODO: Integrate with actual note storage
        // For now, just acknowledge the note
        return '''Note created successfully!
• Title: $title
• Content: ${content.length > 100 ? '${content.substring(0, 100)}...' : content}
• Tags: ${tags.isEmpty ? 'none' : tags}

Note: Full note storage integration coming soon.''';
      },
    );
  }

  /// Create knowledge search tool
  static ToolDefinition _createKnowledgeSearchTool() {
    return ToolDefinition(
      name: 'search_knowledge',
      description: 'Search through previously saved notes, conversations, and knowledge base.',
      type: ToolType.knowledgeSearch,
      parameters: {
        'query': ParameterDefinition(
          type: 'string',
          description: 'The search query',
          required: true,
        ),
        'type': ParameterDefinition(
          type: 'string',
          description: 'Type of content to search: "notes", "conversations", "all"',
          required: false,
          enumValues: ['notes', 'conversations', 'all'],
          defaultValue: 'all',
        ),
      },
      execute: (args) async {
        final query = args['query'] as String;
        final type = args['type'] as String? ?? 'all';

        // TODO: Integrate with actual knowledge base
        return '''Knowledge search for: "$query" (type: $type)

Note: Knowledge base integration coming soon.
For now, use web_search to find information online.''';
      },
    );
  }

  /// Get list of all built-in tool names
  static List<String> get toolNames => [
        'web_search',
        'brave_search',
        'tavily_search',
        'read_url',
        'web_scraper',
        'calculator',
        'unit_converter',
        'datetime',
        'text_processor',
        'create_note',
        'search_knowledge',
      ];

  /// Get tool count
  static int get count => toolNames.length;
}