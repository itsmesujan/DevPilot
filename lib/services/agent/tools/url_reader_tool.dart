import 'package:http/http.dart' as http;
import '../../../models/agent_models.dart';

/// URL reader tool using Jina AI reader (free, no API key required)
class UrlReaderTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'read_url',
        description:
            'Read and extract content from a webpage URL. Returns clean, readable text from the page.',
        type: ToolType.urlReader,
        parameters: {
          'url': ParameterDefinition(
            type: 'string',
            description: 'The URL of the webpage to read',
            required: true,
          ),
          'max_length': ParameterDefinition(
            type: 'number',
            description: 'Maximum characters to return (default: 5000)',
            required: false,
            defaultValue: 5000,
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final maxLength = (args['max_length'] as num?)?.toInt() ?? 5000;

    // Validate URL
    Uri? uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$url');
      }
    } catch (e) {
      return 'Invalid URL: $url';
    }

    try {
      // Use Jina Reader for clean content extraction
      final jinaUrl = 'https://r.jina.ai/${uri.toString()}';
      final response = await http.get(
        Uri.parse(jinaUrl),
        headers: {
          'Accept': 'text/plain',
          'X-No-Cache': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return 'Failed to read URL: ${response.statusCode}';
      }

      var content = response.body;

      // Truncate if too long
      if (content.length > maxLength) {
        content = '${content.substring(0, maxLength)}...\n\n[Content truncated at $maxLength characters]';
      }

      if (content.isEmpty) {
        return 'No content found at: $url';
      }

      return 'Content from $url:\n\n$content';
    } catch (e) {
      return 'Error reading URL: $e';
    }
  }
}

/// Webpage scraper with HTML parsing
class WebScraperTool {
  static ToolDefinition get definition => ToolDefinition(
        name: 'web_scraper',
        description:
            'Scrape a webpage and extract specific elements like links, images, or text content.',
        type: ToolType.urlReader,
        parameters: {
          'url': ParameterDefinition(
            type: 'string',
            description: 'The URL of the webpage to scrape',
            required: true,
          ),
          'extract': ParameterDefinition(
            type: 'string',
            description: 'What to extract: "text", "links", "images", "all"',
            required: false,
            enumValues: ['text', 'links', 'images', 'all'],
            defaultValue: 'text',
          ),
        },
        execute: _execute,
      );

  static Future<String> _execute(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final extract = args['extract'] as String? ?? 'text';

    Uri? uri;
    try {
      uri = Uri.parse(url);
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$url');
      }
    } catch (e) {
      return 'Invalid URL: $url';
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (compatible; DevPilot/1.0; +https://devpilot.app)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 'Failed to scrape: ${response.statusCode}';
      }

      final html = response.body;
      final buffer = StringBuffer();

      if (extract == 'text' || extract == 'all') {
        // Simple text extraction (remove tags)
        final text = html
            .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        buffer.writeln('**Text Content:**\n${text.substring(0, text.length > 3000 ? 3000 : text.length)}...');
      }

      if (extract == 'links' || extract == 'all') {
        // Extract links
        final linkRegex = RegExp(r'<a[^>]+href="([^"]+)"[^>]*>([^<]*)</a>', caseSensitive: false);
        final links = linkRegex.allMatches(html).take(20).map((m) {
          final href = m.group(1) ?? '';
          final text = m.group(2) ?? '';
          return '• [$text]($href)';
        }).join('\n');
        buffer.writeln('\n**Links:**\n$links');
      }

      if (extract == 'images' || extract == 'all') {
        // Extract images
        final imgRegex = RegExp(r'<img[^>]+src="([^"]+)"[^>]*alt="([^"]*)"', caseSensitive: false);
        final images = imgRegex.allMatches(html).take(10).map((m) {
          final src = m.group(1) ?? '';
          final alt = m.group(2) ?? '';
          return '• ![$alt]($src)';
        }).join('\n');
        buffer.writeln('\n**Images:**\n$images');
      }

      return buffer.toString().isEmpty ? 'No content extracted from $url' : buffer.toString();
    } catch (e) {
      return 'Scraper error: $e';
    }
  }
}