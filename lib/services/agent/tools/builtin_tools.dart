import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../models/agent_models.dart';
import '../../storage/app_database.dart';
import '../../memory/memory_service.dart';
import 'tool_registry.dart';
import 'web_search_tool.dart';
import 'url_reader_tool.dart';
import 'calculator_tool.dart';
import 'datetime_tool.dart';
import 'text_processor_tool.dart';
import 'file_tools.dart';
import 'code_tools.dart';
import 'system_tools.dart';
import 'api_tools.dart';

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

    // Knowledge/Note tools — backed by AppDatabase & MemoryService
    registry.register(_createNoteTool());
    registry.register(_createKnowledgeSearchTool());

    // Phase 2: Expanded Ecosystem Tools
    FileTools.registerAll();
    CodeTools.registerAll();
    SystemTools.registerAll();
    ApiTools.registerAll();
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

        final id = const Uuid().v4();
        final noteContent = 'Title: $title\nContent: $content';
        final tagList = tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        final metadata = jsonEncode({
          'title': title,
          'tags': tagList,
        });

        AppDatabase.instance.insertMemory(
          id: id,
          content: noteContent,
          type: 'note',
          metadata: metadata,
          createdAt: DateTime.now().toIso8601String(),
        );

        return '''Note created successfully and saved in database!
• ID: $id
• Title: $title
• Content: ${content.length > 100 ? '${content.substring(0, 100)}...' : content}
• Tags: ${tagList.isEmpty ? 'none' : tagList.join(', ')}''';
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

        final results = StringBuffer();
        results.writeln('Search results for query: "$query" (type: $type)\n');

        bool foundAny = false;

        if (type == 'notes' || type == 'all') {
          final notes = await MemoryService.instance.search(query, type: 'note', topK: 10);
          if (notes.isNotEmpty) {
            foundAny = true;
            results.writeln('=== Saved Notes ===');
            for (int i = 0; i < notes.length; i++) {
              final note = notes[i];
              results.writeln('${i + 1}. ${note.content}');
              results.writeln('   Created: ${note.createdAt.toIso8601String().split('T')[0]}');
              results.writeln();
            }
          }
        }

        if (type == 'conversations' || type == 'all') {
          final messages = AppDatabase.instance.searchMessages(query, limit: 10);
          if (messages.isNotEmpty) {
            foundAny = true;
            results.writeln('=== Chat Conversations ===');
            for (int i = 0; i < messages.length; i++) {
              final msg = messages[i];
              final role = msg['role'] as String;
              final content = msg['content'] as String;
              final sessionId = msg['session_id'] as String;
              final date = (msg['created_at'] as String).split('T')[0];

              results.writeln('${i + 1}. [$role in Session $sessionId] ($date)');
              results.writeln('   "${content.length > 150 ? '${content.substring(0, 150)}...' : content}"');
              results.writeln();
            }
          }
        }

        if (!foundAny) {
          results.writeln('No matching notes or conversations found in the local database.');
          if (type == 'all' || type == 'notes') {
            results.writeln('\nTip: You can use the "create_note" tool to save notes first.');
          }
        }

        return results.toString();
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