import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/agent_models.dart';
import '../../storage/storage_service.dart';

/// Web search tool using DuckDuckGo API (free, no API key required)
class WebSearchTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'web_search',
        description:
            'Search the web for information using DuckDuckGo. Returns relevant results with titles, URLs, and snippets.',
        type: ToolType.webSearch,
        parameters: {
          'query': ParameterDefinition(
            type: 'string',
            description: 'The search query to look up',
            required: true,
          ),
          'max_results': ParameterDefinition(
            type: 'number',
            description: 'Maximum number of results to return (default: 5)',
            required: false,
            defaultValue: 5,
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final query = args['query'] as String;
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;

    final encoded = Uri.encodeQueryComponent(query);
    final url =
        'https://api.duckduckgo.com/?q=$encoded&format=json&no_redirect=1&no_html=1';

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 'Search failed with status ${response.statusCode}';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = <String>[];

      // Get abstract
      final abstractText = json['AbstractText'] as String? ?? '';
      final abstractUrl = json['AbstractURL'] as String? ?? '';
      final heading = json['Heading'] as String? ?? '';

      if (abstractText.isNotEmpty) {
        results.add('**$heading**\n$abstractText\nSource: $abstractUrl');
      }

      // Get related topics
      final related = json['RelatedTopics'] as List? ?? [];
      for (final topic in related.take(maxResults)) {
        if (topic is Map) {
          final text = topic['Text'] as String? ?? '';
          final firstUrl = topic['FirstURL'] as String? ?? '';
          if (text.isNotEmpty && firstUrl.isNotEmpty) {
            results.add('• $text\n  $firstUrl');
          }
        }
      }

      // Get results section
      final relatedResults = json['Results'] as List? ?? [];
      for (final result in relatedResults.take(3)) {
        if (result is Map) {
          final text = result['Text'] as String? ?? '';
          final firstUrl = result['FirstURL'] as String? ?? '';
          if (text.isNotEmpty) {
            results.add('• $text\n  $firstUrl');
          }
        }
      }

      if (results.isEmpty) {
        return 'No results found for: $query';
      }

      return 'Search results for "$query":\n\n${results.join('\n\n')}';
    } catch (e) {
      return 'Search error: $e';
    }
  }
}

/// Alternative web search using Brave Search API
class BraveSearchTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'brave_search',
        description:
            'Search the web using Brave Search API. More comprehensive results than DuckDuckGo. Requires API key.',
        type: ToolType.webSearch,
        parameters: {
          'query': ParameterDefinition(
            type: 'string',
            description: 'The search query to look up',
            required: true,
          ),
          'count': ParameterDefinition(
            type: 'number',
            description: 'Number of results to return (default: 10)',
            required: false,
            defaultValue: 10,
          ),
          'search_lang': ParameterDefinition(
            type: 'string',
            description: 'Search language (e.g., "en", "es", "fr")',
            required: false,
            defaultValue: 'en',
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final query = args['query'] as String;
    final count = (args['count'] as num?)?.toInt() ?? 10;
    final lang = args['search_lang'] as String? ?? 'en';

    final apiKey = await StorageService.instance.getApiKey('brave') ?? '';

    if (apiKey.isEmpty) {
      return 'Brave Search API key not configured. Go to Settings → API Keys and add your Brave key, or use web_search instead.';
    }

    final url = Uri.parse(
      'https://api.search.brave.com/res/v1/web/search?q=${Uri.encodeQueryComponent(query)}&count=$count&search_lang=$lang',
    );

    try {
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'X-Subscription-Token': apiKey,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 'Brave Search failed: ${response.statusCode}';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final web = json['web'] as Map<String, dynamic>?;
      final results = web?['results'] as List? ?? [];

      if (results.isEmpty) {
        return 'No results found for: $query';
      }

      final formatted = results.map((r) {
        final title = r['title'] ?? '';
        final description = r['description'] ?? '';
        final url = r['url'] ?? '';
        return '**$title**\n$description\n$url';
      }).join('\n\n');

      return 'Search results for "$query":\n\n$formatted';
    } catch (e) {
      return 'Brave Search error: $e';
    }
  }
}

/// Tavily search tool for research-grade results
class TavilySearchTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'tavily_search',
        description:
            'Research-grade web search using Tavily API. Returns clean, relevant content optimized for AI analysis.',
        type: ToolType.webSearch,
        parameters: {
          'query': ParameterDefinition(
            type: 'string',
            description: 'The search query',
            required: true,
          ),
          'max_results': ParameterDefinition(
            type: 'number',
            description: 'Maximum results (default: 5)',
            required: false,
            defaultValue: 5,
          ),
          'include_answer': ParameterDefinition(
            type: 'boolean',
            description: 'Include AI-generated answer summary',
            required: false,
            defaultValue: true,
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final query = args['query'] as String;
    final maxResults = (args['max_results'] as num?)?.toInt() ?? 5;
    final includeAnswer = args['include_answer'] as bool? ?? true;

    final apiKey = await StorageService.instance.getApiKey('tavily') ?? '';

    if (apiKey.isEmpty) {
      return 'Tavily API key not configured. Go to Settings → API Keys and add your Tavily key, or use web_search instead.';
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.tavily.com/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'query': query,
          'max_results': maxResults,
          'include_answer': includeAnswer,
          'search_depth': 'advanced',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return 'Tavily search failed: ${response.statusCode}';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final buffer = StringBuffer();

      if (includeAnswer) {
        final answer = json['answer'] as String? ?? '';
        if (answer.isNotEmpty) {
          buffer.writeln('**AI Summary:**\n$answer\n');
        }
      }

      final results = json['results'] as List? ?? [];
      buffer.writeln('**Sources:**');
      for (final r in results) {
        final title = r['title'] ?? '';
        final url = r['url'] ?? '';
        final content = r['content'] ?? '';
        buffer.writeln('\n• **$title**\n  $content\n  $url');
      }

      return buffer.toString();
    } catch (e) {
      return 'Tavily search error: $e';
    }
  }
}